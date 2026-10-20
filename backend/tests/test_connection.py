import os
import unittest
from unittest.mock import patch
from src.database import connect


class ConnectionTests(unittest.TestCase):
    def test_cloud_connection_verifies_certificate_and_hostname(self):
        settings = dict(FINAL_EXODUS_DB_HOST='project.example.aivencloud.com',
                        FINAL_EXODUS_DB_PORT='12345', FINAL_EXODUS_DB_USER='app',
                        FINAL_EXODUS_DB_PASSWORD='test-only', FINAL_EXODUS_DB='game',
                        FINAL_EXODUS_DB_SSL_CA='/tmp/test-ca.pem')
        with patch.dict(os.environ, settings, clear=True), patch('src.database.pymysql.connect') as mysql:
            connect()
        actual = mysql.call_args.kwargs
        self.assertEqual(actual['host'], settings['FINAL_EXODUS_DB_HOST'])
        self.assertEqual(actual['port'], 12345)
        self.assertEqual(actual['ssl_ca'], '/tmp/test-ca.pem')
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

    def test_remote_database_without_certificate_is_rejected(self):
        settings = dict(FINAL_EXODUS_DB_HOST='remote.example.com', FINAL_EXODUS_DB_USER='app', FINAL_EXODUS_DB_PASSWORD='test-only')
        with patch.dict(os.environ, settings, clear=True), patch('src.database.pymysql.connect') as mysql:
            with self.assertRaises(ValueError):
                connect()
            mysql.assert_not_called()
