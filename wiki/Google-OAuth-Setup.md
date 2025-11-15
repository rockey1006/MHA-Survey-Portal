# Google OAuth Setup

This guide walks through creating a Google OAuth 2.0 client and wiring the credentials into the Health application for both local development and deployed environments.

## 1. Create a Google Cloud project

1. Visit the [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project (e.g., `Health App`) or select an existing one reserved for TAMU projects.
3. Note the **Project ID**—you will need it when managing credentials later.

## 2. Configure the OAuth consent screen

1. In the left navigation, go to **APIs & Services → OAuth consent screen**.
2. Choose **Internal** if your Google Workspace restricts sign-in to TAMU members; otherwise use **External**.
3. Fill out the application name, support email, and developer contact information.
4. Add the authorized domain (e.g., `tamu.edu` for production) if required by your Workspace settings.
5. Save the consent screen; scopes for Google user profile are added automatically when you create the client below.

## 3. Create OAuth client credentials

1. Navigate to **APIs & Services → Credentials**.
2. Click **Create Credentials → OAuth client ID**.
3. Select **Web application**.
4. Add authorized JavaScript origins and redirect URIs:
   - Local development:
     - `http://localhost:3000`
     - `http://localhost:3000/users/auth/google_oauth2/callback`
   - Docker development (if bound to a different host/port) or staging URLs.
   - Production deployment:
     - `https://<your-heroku-app>.herokuapp.com`
     - `https://<your-heroku-app>.herokuapp.com/users/auth/google_oauth2/callback`
5. Create the client and download the JSON or copy the **Client ID** and **Client Secret** immediately.

## 4. Store credentials for each environment

### Local development

- Rails reads `ENV["GOOGLE_OAUTH_CLIENT_ID"]` and `ENV["GOOGLE_OAUTH_CLIENT_SECRET"]` in `config/initializers/devise.rb`.
- Recommended storage options:
  - Use encrypted credentials with `bin/rails credentials:edit` and add:

    ```yaml
    google_oauth:
      client_id: YOUR_CLIENT_ID
      client_secret: YOUR_CLIENT_SECRET
    ```

    Then expose them in an initializer (see below).
  - Or place them in a local `.env` file if you are using shell exports (see [Local Environment Variables](Local-Environment-Variables.md)).
- To surface credential values back into ENV, add to `config/application.rb` or a dedicated initializer:
  
  ```ruby
  google_config = Rails.application.credentials.dig(:google_oauth)
  ENV["GOOGLE_OAUTH_CLIENT_ID"] ||= google_config&.dig(:client_id)
  ENV["GOOGLE_OAUTH_CLIENT_SECRET"] ||= google_config&.dig(:client_secret)
  ```

  The project currently sets development defaults in `config/environments/development.rb`; override them if you need your own Google project.

### Heroku

1. Set the config vars so they are available to the dynos:

   ```sh
   heroku config:set GOOGLE_OAUTH_CLIENT_ID=... GOOGLE_OAUTH_CLIENT_SECRET=... -a <app-name>
   ```

2. Confirm they are present:

   ```sh
   heroku config -a <app-name>
   ```

3. Restart the app or deploy to pick up the new values.

### Other deployments (Docker, Kamal, etc.)

- Add the variables to your orchestrator (Docker Compose `.env`, Kubernetes secrets, Kamal `.env` files) so that `ENV.fetch` resolves correctly.
- Never commit plain-text secrets to the repository.

## 5. Verify the integration

1. Start the app (`bin/dev` or `docker compose up`).
2. Visit `/users/sign_in` and click **Sign in with Google**.
3. Approve the consent prompt with an authorized Google account.
4. The app should create or update the `User` record via `Users::OmniauthCallbacksController`.

If you receive an `redirect_uri_mismatch` error, ensure the URI hitting Google exactly matches one of the authorized redirect URIs in step 3.

## 6. Testing without Google

For development environments without external network access, you can mock the OmniAuth response:

```ruby
# config/initializers/omniauth_test.rb
if Rails.env.development? && ENV["MOCK_GOOGLE_OAUTH"].present?
  OmniAuth.config.test_mode = true
  OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
    provider: "google_oauth2",
    uid: SecureRandom.uuid,
    info: {
      email: "health-admin1@tamu.edu",
      name: "Health Admin One"
    }
  })
end
```

Enable it with `MOCK_GOOGLE_OAUTH=1 bin/dev`. Remember to disable mock mode before manual testing of the real Google flow.

## 7. Rotating credentials

- Repeat step 3 to generate a new client when rotating secrets; delete the previous credential in Google Cloud Console.
- Update environment variables in every environment and restart the application.
- Inform the team so staging/production configs stay in sync.
