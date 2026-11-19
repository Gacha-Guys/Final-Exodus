import os
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
from src.database import connect


class ConnectionTests(unittest.TestCase):
    def test_cloud_connection_verifies_certificate_and_hostname(self):
        settings = dict(FINAL_EXODUS_DB_HOST='project.example.aivencloud.com',
                        FINAL_EXODUS_DB_PORT='12345', FINAL_EXODUS_DB_USER='app',
                        FINAL_EXODUS_DB_PASSWORD='test-only', FINAL_EXODUS_DB='game')
        with TemporaryDirectory() as directory:
            certificate = Path(directory) / 'custom-ca.pem'
            certificate.touch()
            settings['FINAL_EXODUS_DB_SSL_CA'] = str(certificate)
            with patch.dict(os.environ, settings, clear=True), patch('src.database.pymysql.connect') as mysql:
                connect()
        actual = mysql.call_args.kwargs
        self.assertEqual(actual['host'], settings['FINAL_EXODUS_DB_HOST'])
        self.assertEqual(actual['port'], 12345)
        self.assertEqual(actual['ssl_ca'], str(certificate))
        self.assertIs(actual['ssl_verify_cert'], True)
        self.assertIs(actual['ssl_verify_identity'], True)
        self.assertIs(actual['autocommit'], False)

    def test_local_socket_configuration_preserved(self):
        settings = dict(FINAL_EXODUS_DB_USER='local', FINAL_EXODUS_DB_PASSWORD='',
                        FINAL_EXODUS_DB_SOCKET='/tmp/mysql.sock')
        with patch.dict(os.environ, settings, clear=True), patch('src.database.pymysql.connect') as mysql:
            connect()
        self.assertEqual(mysql.call_args.kwargs['unix_socket'], '/tmp/mysql.sock')
        self.assertNotIn('ssl_ca', mysql.call_args.kwargs)

    def test_remote_certificate_paths_are_relative_to_backend(self):
        settings = dict(FINAL_EXODUS_DB_HOST='remote.example.com',
                        FINAL_EXODUS_DB_USER='app', FINAL_EXODUS_DB_PASSWORD='test-only')
        with TemporaryDirectory() as directory:
            backend = Path(directory)
            (backend / 'certs').mkdir()
            (backend / 'certs/ca.pem').touch()
            (backend / 'certs/custom.pem').touch()
            with patch.dict(os.environ, settings, clear=True), patch('src.database.BACKEND_DIR', backend), \
                    patch('src.database.pymysql.connect') as mysql:
                connect()
                self.assertEqual(mysql.call_args.kwargs['ssl_ca'], str(backend / 'certs/ca.pem'))
                os.environ['FINAL_EXODUS_DB_SSL_CA'] = 'certs/custom.pem'
                connect()
                self.assertEqual(mysql.call_args.kwargs['ssl_ca'], str(backend / 'certs/custom.pem'))

    def test_remote_database_without_certificate_is_rejected(self):
        settings = dict(FINAL_EXODUS_DB_HOST='remote.example.com',
                        FINAL_EXODUS_DB_USER='app', FINAL_EXODUS_DB_PASSWORD='test-only')
        with TemporaryDirectory() as directory:
            backend = Path(directory)
            with patch.dict(os.environ, settings, clear=True), patch('src.database.BACKEND_DIR', backend), \
                    patch('src.database.pymysql.connect') as mysql:
                with self.assertRaisesRegex(ValueError, 'backend/certs/ca.pem'):
                    connect()

                (backend / 'certs').mkdir()
                (backend / 'certs/ca.pem').touch()
                os.environ['FINAL_EXODUS_DB_SSL_CA'] = 'missing.pem'
                with self.assertRaisesRegex(ValueError, 'FINAL_EXODUS_DB_SSL_CA'):
                    connect()

                mysql.assert_not_called()
