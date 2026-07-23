import os

SECRET_KEY = os.environ.get('SUPERSET_SECRET_KEY', 'SECRET')

ROW_LIMIT = 5000
SUPERSET_WORKERS = 4
ENABLE_PROXY_FIX=True

CACHE_CONFIG = {
    'CACHE_TYPE': 'redis',
    'CACHE_DEFAULT_TIMEOUT': 300,
    'CACHE_KEY_PREFIX': 'superset_',
    'CACHE_REDIS_URL': f"redis://{os.environ.get('REDIS_URI')}/1"
}

DB_CONFIG = {
    'USERNAME': os.environ.get('POSTGRES_SUPERSET_USER'),
    'PASSWORD': os.environ.get('POSTGRES_SUPERSET_PASSWORD'),
    'HOST': os.environ.get('POSTGRES_SUPERSET_HOST'),
    'PORT': os.environ.get('POSTGRES_SUPERSET_PORT'),
    'DB': os.environ.get('POSTGRES_SUPERSET_DB')
}
SQLALCHEMY_DATABASE_URI = 'postgresql+psycopg2://{USERNAME}:{PASSWORD}@{HOST}:{PORT}/{DB}'.format(**DB_CONFIG)

SUPERSET_WEBSERVER_TIMEOUT = 60000

## Custom user info
SQLLAB_TIMEOUT = 60000
WTF_CSRF_ENABLED = False

TALISMAN_ENABLED = False
ENABLE_CORS = True
HTTP_HEADERS = {
    "X-Frame-Options": "ALLOWALL"
}

import os
import requests
from flask_appbuilder.security.manager import AUTH_OID, AUTH_REMOTE_USER, AUTH_DB, AUTH_LDAP, AUTH_OAUTH
from superset.security import SupersetSecurityManager

ENABLE_PROXY_FIX = True
AUTH_TYPE = AUTH_OAUTH
BASE_URL = os.environ.get('DSM_OAUTH_INTERNAL_ADDRESS') or os.environ.get('DSM_OAUTH_DOMAIN')

OAUTH_PROVIDERS = [
    {
        'name': 'moma',
        'icon': '',
        'token_key': 'access_token',
        'remote_app': {
            'client_id': os.environ.get('DSM_OAUTH_CLIENT_ID', None),
            'client_secret': os.environ.get('DSM_OAUTH_CLIENT_SECRET', None),
            'client_kwargs': {
                'scope': 'read'
            },
            'authorize_url': f"{os.environ.get('DSM_OAUTH_DOMAIN',None)}/o/authorize",
            'access_token_url': f"{BASE_URL}/o/token/",
        }
    }
]

# --- Security & Role Configurations ---
AUTH_USER_REGISTRATION = True
# Recommendation: Set default registration role to the lowest privilege (Gamma) instead of Admin
AUTH_USER_REGISTRATION_ROLE = "Gamma" 

# Map the custom keys returned by oauth_user_info to actual Superset roles
AUTH_ROLES_MAPPING = {
    "provider_admin": ["Admin"],
    "provider_user": ["Gamma"], # Gamma is standard read-only. Use "Alpha" if they need to create charts/dashboards.
}

# Force Superset to update the user's role on every login (in case their superuser status changes)
AUTH_ROLES_SYNC_AT_LOGIN = True

AUTH_ROLE_PUBLIC = 'Public'
PUBLIC_ROLE_LIKE = "Alpha"


class CustomSsoSecurityManager(SupersetSecurityManager):
    def oauth_user_info(self, provider, response=None):
        BASE_URL = os.environ.get('DSM_OAUTH_INTERNAL_ADDRESS') or os.environ.get('DSM_OAUTH_DOMAIN')
        
        res = requests.get(f"{BASE_URL}/api/v1/account/me", 
            headers={
                'Authorization': f"Bearer {response['access_token']}"
            }
        )

        me = res.json()
        
        # Determine the role key based on the 'is_superuser' flag
        is_super = me.get('is_superuser', False)
        role_keys = ['provider_admin'] if is_super else ['provider_user']

        return {
            'id': me.get('id'), 
            'username': me.get('username'), 
            'name': me.get('username'), 
            'email': me.get('email'), 
            'first_name': me.get('first_name'), 
            'last_name': me.get('last_name'),
            'role_keys': role_keys  # Pass the roles to Flask-AppBuilder
        }

CUSTOM_SECURITY_MANAGER = CustomSsoSecurityManager
