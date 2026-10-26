"""JWT rejection paths and Google flow tests. Google responses are simulated."""
from datetime import datetime, timedelta, timezone
import json
import os
from types import SimpleNamespace
from urllib.parse import parse_qs, urlsplit
from uuid import uuid4

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID
from fastapi.testclient import TestClient
import httpx
import jwt
import pytest

from test_demo_integration import isolated_test_accounts, register, signed_in, PASSWORD
from src import demo, demo_google as google, demo_tokens as tokens
from src.demo_store import transaction


@pytest.fixture(autouse=True)
def google_config(monkeypatch):
    monkeypatch.setenv('FINAL_EXODUS_GOOGLE_CLIENT_ID', 'local-test.apps.googleusercontent.com')
    monkeypatch.setenv('FINAL_EXODUS_GOOGLE_CLIENT_SECRET', 'fake-test-client-secret')
    google.flows.clear()
    yield
    google.flows.clear()


def begin(client):
    response = client.post('/auth/google/start')
    assert response.status_code == 200, response.text
    data = response.json()
    query = parse_qs(urlsplit(data['authorization_url']).query)
    assert query['scope'] == ['openid email profile']
    assert query['code_challenge_method'] == ['S256']
    assert query['redirect_uri'] == [google.REDIRECT]
    assert query['state'] == [data['flow_id']]
    assert data['poll_secret'] not in data['authorization_url']
    assert 'client_secret' not in data['authorization_url']
    return {k: data[k] for k in ('flow_id', 'poll_secret')}


def identity(created):
    email = f'google-{uuid4().hex}@example.com'
    created.append(email)
    return dict(subject=uuid4().hex, email=email, display_name='Google Player')


def verified_flow(client, monkeypatch, who):
    key = begin(client)
    monkeypatch.setattr(google, 'verified_identity', lambda code, flow: who)
    response = client.get('/auth/google/callback', params=dict(state=key['flow_id'], code='private-authorization-code'))
    assert response.status_code == 200
    assert 'private-authorization-code' not in response.text
    assert response.headers['Referrer-Policy'] == 'no-referrer'
    return key


def test_jwt_contract_and_openapi(isolated_test_accounts):
    client, headers, account = signed_in(isolated_test_accounts)
    token = headers['Authorization'][7:]
    claims = jwt.decode(token, tokens.signing_key(), algorithms=['HS256'], audience=tokens.AUDIENCE, issuer=tokens.ISSUER)
    assert claims['sub'] == str(account['id']) and claims['exp'] - claims['iat'] == 900
    assert all(k in claims for k in ('nbf','jti'))
    assert 'email' not in claims and 'password' not in claims
    response = client.get('/me', headers=headers)
    assert response.status_code == 200 and response.headers['cache-control'] == 'no-store'
    schema = client.get('/openapi.json').json()
    assert schema['components']['securitySchemes']['HTTPBearer']['bearerFormat'] == 'JWT'
    assert schema['paths']['/me']['get']['security'] == [{'HTTPBearer': []}]
    assert client.get('/me').headers['www-authenticate'] == 'Bearer'


@pytest.mark.parametrize('change', ['expired','future','issuer','audience','subject','missing','algorithm','signature','none'])
def test_forged_jwt_denied_even_if_recorded_in_database(isolated_test_accounts, change):
    client, headers, account = signed_in(isolated_test_accounts)
    claims = jwt.decode(headers['Authorization'][7:], tokens.signing_key(), algorithms=['HS256'], audience=tokens.AUDIENCE)
    algorithm, key = 'HS256', tokens.signing_key()
    if change == 'expired': claims['exp'] = int(datetime.now(timezone.utc).timestamp())-10
    if change == 'future': claims['nbf'] += 3600
    if change == 'issuer': claims['iss'] = 'attacker'
    if change == 'audience': claims['aud'] = 'other-app'
    if change == 'subject': claims['sub'] = str(account['id']+1)
    if change == 'missing': del claims['jti']
    if change == 'algorithm': algorithm = 'HS512'
    if change == 'signature': key = 'wrong-key-'*8
    if change == 'none': algorithm, key = 'none', None
    forged = jwt.encode(claims, key, algorithm=algorithm)
    with transaction() as cursor:
        cursor.execute('INSERT INTO DemoSessions(token_hash,u_id,expires_at) VALUES(%s,%s,%s)',
                       (tokens.token_hash(forged), account['id'], datetime.now()+timedelta(hours=1)))
    assert client.get('/me', headers={'Authorization':'Bearer '+forged}).status_code == 401
    assert client.get('/battles/current', headers={'Authorization':'Bearer '+forged}).status_code == 401


def test_missing_signing_key_fails_closed(isolated_test_accounts, monkeypatch):
    client, body, _ = register(isolated_test_accounts)
    monkeypatch.delenv('FINAL_EXODUS_JWT_SECRET')
    assert client.post('/sessions', json=dict(email=body['email'],password=PASSWORD)).status_code == 503


def test_google_unconfigured_and_state_replay(monkeypatch):
    client = TestClient(demo.app)
    monkeypatch.delenv('FINAL_EXODUS_GOOGLE_CLIENT_SECRET')
    assert client.post('/auth/google/start').status_code == 503
    monkeypatch.setenv('FINAL_EXODUS_GOOGLE_CLIENT_SECRET','fake-test-client-secret')
    key = begin(client)
    assert client.post('/auth/google/poll',json=key).json() == {'status':'pending'}
    assert client.post('/auth/google/poll',json=key | {'poll_secret':'x'*43}).status_code == 400
    assert client.get('/auth/google/callback', params={'state':'x'*43,'code':'code'}).status_code == 400
    assert client.get('/auth/google/callback', params={'state':key['flow_id'],'error':'access_denied'}).status_code == 200
    assert client.get('/auth/google/callback', params={'state':key['flow_id'],'code':'code'}).status_code == 400
    assert client.post('/auth/google/poll',json=key).status_code == 400


def test_google_registration_returning_user_logout_and_no_password(isolated_test_accounts, monkeypatch):
    client = TestClient(demo.app)
    who = identity(isolated_test_accounts)
    key = verified_flow(client, monkeypatch, who)
    assert client.post('/auth/google/poll',json=key).json()['status'] == 'registration_required'
    assert client.post('/auth/google/register',json=key | dict(display_name='Player',dob='2999-01-01')).status_code == 422
    response = client.post('/auth/google/register',json=key | dict(display_name='Google Tester',dob='2000-01-01'))
    assert response.status_code == 200, response.text
    headers = {'Authorization':'Bearer '+response.json()['access_token']}
    profile = client.get('/me',headers=headers).json()
    assert profile['email'] == who['email'] and profile['free_currency'] == 0
    assert client.post('/auth/google/poll',json=key).status_code == 400
    assert client.post('/sessions',json=dict(email=who['email'],password='!google-only')).status_code == 401
    assert client.delete('/sessions/current',headers=headers).status_code == 204
    assert client.get('/me',headers=headers).status_code == 401
    # Stable provider subject finds the same account even if Google's email changes.
    key = verified_flow(client, monkeypatch, who | {'email':'changed@example.com'})
    response = client.post('/auth/google/poll',json=key)
    assert response.json()['status'] == 'authenticated'
    headers = {'Authorization':'Bearer '+response.json()['access_token']}
    assert client.get('/me',headers=headers).json()['id'] == profile['id']


def test_google_does_not_link_matching_email(isolated_test_accounts, monkeypatch):
    client, body, account = register(isolated_test_accounts)
    key = verified_flow(client,monkeypatch,dict(subject=uuid4().hex,email=body['email'],display_name='Someone'))
    assert client.post('/auth/google/poll',json=key).status_code == 409
    assert client.post('/auth/google/register',json=key | dict(display_name='Someone',dob='2000-01-01')).status_code == 409
    with transaction() as cursor:
        cursor.execute('SELECT * FROM DemoGoogleIdentities WHERE u_id=%s',(account['id'],))
        assert cursor.fetchone() is None


def test_google_cancel_expiry_capacity_and_early_registration(monkeypatch):
    client = TestClient(demo.app)
    key = begin(client)
    assert client.post('/auth/google/register',json=key | dict(display_name='No',dob='2000-01-01')).status_code == 400
    assert client.post('/auth/google/cancel',json=key).status_code == 204
    assert client.post('/auth/google/poll',json=key).status_code == 400
    key = begin(client)
    google.flows[key['flow_id']].expires = 0
    assert client.post('/auth/google/poll',json=key).status_code == 400
    google.flows.update({str(i):google.Flow('hash','nonce','verifier',float('inf')) for i in range(100)})
    assert client.post('/auth/google/start').status_code == 429


@pytest.mark.parametrize('change',['valid','audience','issuer','signature','expired','nonce','unverified','subject'])
def test_actual_google_id_token_verification(monkeypatch, change):
    private = rsa.generate_private_key(public_exponent=65537,key_size=2048)
    now = datetime.now(timezone.utc)
    subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'Local test certificate')])
    cert = (x509.CertificateBuilder().subject_name(subject).issuer_name(subject).public_key(private.public_key())
            .serial_number(x509.random_serial_number()).not_valid_before(now-timedelta(minutes=1))
            .not_valid_after(now+timedelta(hours=1)).sign(private, hashes.SHA256()))
    claims = dict(iss='https://accounts.google.com',aud=os.environ['FINAL_EXODUS_GOOGLE_CLIENT_ID'],
                  sub='google-subject',email='google@example.com',email_verified=True,nonce='expected-nonce',
                  iat=int(now.timestamp()),exp=int((now+timedelta(minutes=5)).timestamp()))
    if change == 'audience': claims['aud'] = 'other-client'
    if change == 'issuer': claims['iss'] = 'https://attacker.example'
    if change == 'expired': claims['exp'] = int(now.timestamp())-10
    if change == 'nonce': claims['nonce'] = 'wrong'
    if change == 'unverified': claims['email_verified'] = False
    if change == 'subject': del claims['sub']
    signing = rsa.generate_private_key(public_exponent=65537,key_size=2048) if change == 'signature' else private
    token = jwt.encode(claims, signing, algorithm='RS256',headers={'kid':'test-cert'})
    real_client = httpx.Client
    def exchange(request):
        assert request.url == google.TOKEN_ENDPOINT
        assert b'code_verifier=verifier' in request.content
        return httpx.Response(200,json={'id_token':token})
    monkeypatch.setattr(google.httpx,'Client',lambda **kwargs: real_client(transport=httpx.MockTransport(exchange),**kwargs))
    cert_body = json.dumps({'test-cert':cert.public_bytes(serialization.Encoding.PEM).decode()}).encode()
    def cert_request(**kwargs):
        assert kwargs['url'] == 'https://www.googleapis.com/oauth2/v1/certs' and kwargs['timeout'] == 5
        return SimpleNamespace(status=200,data=cert_body)
    monkeypatch.setattr(google,'GoogleRequest',lambda:cert_request)
    flow = google.Flow('poll-hash','expected-nonce','verifier',float('inf'))
    if change == 'valid':
        assert google.verified_identity('code',flow)['subject'] == 'google-subject'
    else:
        with pytest.raises((ValueError, google.GoogleAuthError)):
            google.verified_identity('code',flow)
