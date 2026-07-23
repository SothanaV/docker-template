gitlab_rails['omniauth_enabled'] = true
gitlab_rails['omniauth_allow_single_sign_on'] = ['oauth2_generic']
gitlab_rails['omniauth_block_auto_created_users'] = false # Set to true if you want to manual approve new users
gitlab_rails['omniauth_external_providers'] = []

gitlab_rails['omniauth_providers'] = [
  {
    name: "oauth2_generic",
    label: "MOMA", # The text on the login button
    app_id: "",
    app_secret: "",
    args: {
      client_options: {
        site: "https://oauth-xxx.com", # Base URL of your provider
        user_info_url: "/api/v1/account/me",
        authorize_url: "/o/authorize/",
        token_url: "/o/token/",
        connection_opts: { ssl: { verify: false } }
      },
      user_response_structure: {
        attributes: {
          nickname: "username", # Maps JSON 'username' to GitLab nickname
          name: "username", # Maps JSON 'username' to GitLab name
          email: "email",
          admin: "is_superuser"
        }
      },
      strategy_class: "OmniAuth::Strategies::OAuth2Generic"
    }
  }
]