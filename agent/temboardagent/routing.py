import re
import logging

ROUTES = []
WORKERS = []

logger = logging.getLogger(__name__)


def make_route(function, method, path, public=False):
    # If public, authentication is not enforced.
    splitpath = []
    elts = path.split(b'/')
    pos = 0
    root = None
    # Seeking for regexp in the path, because we need to compile it.
    for elt in elts:
        if len(elt) == 0:
            continue

        # python 3
        if type(elt) is bytes and type(elt) is not str and \
           chr(elt[0]) == '(' and chr(elt[-1]) == ')':
            elt = elt.decode('utf-8')

        # regexp have to start with a ( end is terminated by a ).
        if type(elt) is str and elt[0] == '(' and elt[-1] == ')':
            # Append it compiled.
            splitpath.append(re.compile(elt))
        # string case
        else:
            if pos == 0:
                root = elt
            splitpath.append(elt)
        pos += 1
    # A path can't start with a regexp.
    if root is None:
        raise Exception("Wrong route format.")
    return dict(
        http_method=method,
        root=root,
        path=path,
        splitpath=splitpath,
        module=function.__module__,
        function=function.__name__,
        public=public,
    )


def get_routes():
    """
    Returns the routes.
    """
    return ROUTES


class Router:
    # Adapter to manage routes with an instance rather than a global.

    def add(self, routes):
        global ROUTES
        for route in routes:
            if route not in ROUTES:
                ROUTES.append(route)

    def remove(self, routes):
        global ROUTES
        for route in routes:
            if route in ROUTES:
                ROUTES.remove(route)


class RouteSet(list):
    def __init__(self, prefix=b''):
        self.prefix = prefix

    def delete(self, path, public=False):
        def register_route(f):
            self.append(make_route(f, 'DELETE', self.prefix + path, public))
            return f
        return register_route

    def get(self, path, public=False):
        def register_route(f):
            self.append(make_route(f, 'GET', self.prefix + path, public))
            return f
        return register_route

    def post(self, path, public=False):
        def register_route(f):
            self.append(make_route(f, 'POST', self.prefix + path, public))
            return f
        return register_route
