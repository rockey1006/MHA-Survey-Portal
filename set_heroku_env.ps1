# Heroku Environment Variables Setup Script
# Setting up Google OAuth credentials for Health app

$APP_NAME = "health-501-production"  # Production app

# Set Google OAuth environment variables
Write-Host "Setting Google OAuth environment variables for $APP_NAME..."

# Google OAuth credentials
heroku config:set GOOGLE_OAUTH_CLIENT_ID="215660362596-omhh55a28t2ogjasr51aro8rvlkmnolk.apps.googleusercontent.com" --app $APP_NAME
heroku config:set GOOGLE_OAUTH_CLIENT_SECRET="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" --app $APP_NAME

# Set Rails environment variables
heroku config:set RAILS_ENV="production" --app $APP_NAME
heroku config:set RAILS_SERVE_STATIC_FILES="true" --app $APP_NAME

# Display current config
Write-Host "Current config variables:"
heroku config --app $APP_NAME