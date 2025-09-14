#!/bin/sh

ROOT_DIR=/app

# Replace env vars in files served by NGINX
for file in $ROOT_DIR/assets/*.js* $ROOT_DIR/index.html;
do
  sed -i 's|VITE_API_URL_PLACEHOLDER|'${VITE_API_URL}'|g' $file
  sed -i 's|VITE_FRONTEND_URL_PLACEHOLDER|'${VITE_FRONTEND_URL}'|g' $file
  # Your other variables here...
done
# Starting NGINX
nginx -g 'daemon off;'
