import http.client
import json
import logging
import ssl
from time import time

from .toolkit.utils import ensure_bytes
from .toolkit.errors import TemboardError
from .toolkit.pycompat import PY2, HTTPError

try:
    ConnectionError = ConnectionError
except NameError:  # python2
    from socket import error as ConnectionError


logger = logging.getLogger(__name__)


class TemboardAgentError(TemboardError):
    def __init__(self, response):
        self.response = response
        self._message = None
        super(TemboardAgentError, self).__init__(response.status, self.message)

    @property
    def message(self):
        if not self._message:
            try:
                json = self.response.json()
                self._message = json['error']
            except Exception:
                self._message = self.response.reason
        return self._message

    def __str__(self):
        return '%s: %s' % (self.response.status, self.message)

    def __repr__(self):
        return '<%s %s>' % (self.__class__.__name__, self)


class TemboardAgentClient(object):
    ConnectionError = ConnectionError
    Error = TemboardAgentError

    @classmethod
    def factory(cls, config, host, port, key=None):
        return cls(
            host, port,
            ca_cert_file=config.temboard.ssl_ca_cert_file,
            key=key,
        )

    def __init__(self, host, port, ca_cert_file=None, key=None):
        """ If ca_cert_file is None, HTTPS connection is unverified. """
        self.host = host
        self.port = port
        self.ca_cert_file = ca_cert_file
        self.key = key  # Authentication key
        self._ssl_context = None

    def __repr__(self):
        return '<%s %s:%s %s>' % (
            self.__class__.__name__,
            self.host, self.port,
            'verified' if self.ca_cert_file else 'unverified',
        )

    @property
    def ssl_context(self):
        if self._ssl_context is None:
            self._ssl_context = ssl.create_default_context(
                cafile=self.ca_cert_file,
            )
            if self.ca_cert_file:
                self._ssl_context.verify_mode = ssl.CERT_REQUIRED
            else:

                self._ssl_context.check_hostname = False
                self._ssl_context.verify_mode = ssl.CERT_NONE
        return self._ssl_context

    def request(self, method, path, headers=None, body=None):
        fullurl = 'https://%s:%s%s' % (self.host, self.port, path)
        headers = headers or {}

        if self.key:
            headers['X-TemBoard-Agent-Key'] = self.key

        if body:
            headers['Content-Type'] = 'application/json'

        if hasattr(body, 'pop'):  # list or dict
            body = json.dumps(body)

        body = ensure_bytes(body)

        logger.debug("Requesting %s %s.", method, fullurl)
        conn = http.client.HTTPSConnection(
            self.host, self.port, context=self.ssl_context, timeout=30,
        )
        conn.response_class = TemboardAgentResponse
        start_time = time()
        conn.request(method, fullurl, body, headers)
        response = conn.getresponse()
        duration = time() - start_time
        response.path = path
        logger.debug(
            "Response from %s:%s in %.3fs: %s.",
            self.host, self.port, duration, response)
        return response

    def get(self, path, headers=None):
        return self.request('GET', path, headers)

    def post(self, path, body, headers=None):
        return self.request('POST', path, headers)


class TemboardAgentResponse(http.client.HTTPResponse):
    # Extensions to HTTPResponse, inspired by httpx

    if PY2:
        @property
        def headers(self):
            return dict(self.getheaders())

    def __str__(self):
        return '%s %s' % (self.status, self.reason)

    def __repr__(self):
        return '<%s %s %s -> %s %s %s>' % (
            self.__class__.__name__,
            self._method, self.path,
            self.status, self.reason,
            'closed' if self.isclosed() else 'opened',
        )

    def raise_for_status(self):
        if self.status >= 400:
            raise TemboardAgentError(self)
        elif self.status >= 300:
            raise HTTPError(self.status, self.reason)

    def json(self):
        return json.loads(self.read().decode('utf-8'))
