#!/bin/sh

ROOT_DIR=/app

# Replace env vars in files served by NGINX
for file in /app/assets/*.js /app/assets/*.js* /app/index.html /app/precache-manifest*.js;
do
  sed -i 's|BASE_API_PLACEHOLDER|'${BASE_API}'|g' $file
  sed -i 's|FRONTEND_CALLBACK_PLACEHOLDER|'${FRONTEND_CALLBACK}'|g' $file
  # Your other variables here...
done
# Starting NGINX
nginx -g 'daemon off;'