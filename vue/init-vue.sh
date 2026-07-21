#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ -z "$1" ]; then
    echo -e "${RED}Error: Project name is required${NC}"
    echo "Usage: $0 <project-name>"
    echo "Example: $0 my-vue-app"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating Vue project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   Vue Project Features${NC}"
echo -e "${CYAN}══════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}Select TypeScript:${NC}"
echo "  1) TypeScript (default)"
echo "  2) JavaScript"
read -p "  Enter choice [1]: " ts_choice
ts_choice="${ts_choice:-1}"
case $ts_choice in
    1) SELECT_TS="yes" ;;
    2) SELECT_TS="no" ;;
esac

echo -e "\n${YELLOW}Select state management:${NC}"
echo "  1) Pinia (default)"
echo "  2) VueX"
echo "  3) None"
read -p "  Enter choice [1]: " state_choice
state_choice="${state_choice:-1}"
case $state_choice in
    1) SELECT_STATE="pinia" ;;
    2) SELECT_STATE="vux" ;;
    3) SELECT_STATE="none" ;;
esac

echo -e "\n${YELLOW}Select CSS approach:${NC}"
echo "  1) Tailwind CSS (default)"
echo "  2) SCSS"
echo "  3) Vanilla CSS"
read -p "  Enter choice [1]: " css_choice
css_choice="${css_choice:-1}"
case $css_choice in
    1) SELECT_CSS="tailwind" ;;
    2) SELECT_CSS="scss" ;;
    3) SELECT_CSS="vanilla" ;;
esac

create_file() {
    local path="$1"
    local content="$2"
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
    echo -e "${GREEN}Created:${NC} $path"
}

LANG_EXT="ts"
if [ "$SELECT_TS" = "no" ]; then
    LANG_EXT="js"
fi

create_file "$PROJECT_DIR/.env" \
"VITE_API_URL=http://localhost:5050/api
VITE_APP_NAME='$PROJECT_NAME'
"

dockerfile_content="services:
    frontend:
        container_name: \${PROJECT_NAME}-frontend
        build: ./frontend
        volumes:
            - ./frontend:/frontend
        ports:
            - \"3000:3000\"
        env_file:
            - .env
        healthcheck:
            test: [\"CMD\", \"node\", \"-e\", \"fetch('http://localhost:3000')\" ]
            interval: 30s
            timeout: 10s
            retries: 3
            start_period: 40s
        restart: unless-stopped
"

create_file "$PROJECT_DIR/docker-compose.yml", "$dockerfile_content"

# ---- FRONTEND DOCKERFILE ----
create_file "$PROJECT_DIR/frontend/Dockerfile" "FROM node:20-alpine AS build
WORKDIR /frontend
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /frontend/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD [\"nginx\", \"-g\", \"daemon off;\"]
"

create_file "$PROJECT_DIR/frontend/nginx.conf" "server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
"

# ---- Package.json ----
state_deps=""
if [ "$SELECT_STATE" = "pinia" ]; then
    state_deps="\"pinia\": \"^2.1.7\""
elif [ "$SELECT_STATE" = "vux" ]; then
    state_deps="\"vuex\": \"^4.1.0\""
fi

css_deps=""
if [ "$SELECT_CSS" = "tailwind" ]; then
    css_deps="'$state_deps',
    \"autoprefixer\": \"^10.4.19\",
    \"postcss\": \"^8.4.38\",
    \"tailwindcss\": \"^3.4.4\""
elif [ "$SELECT_CSS" = "scss" ]; then
    css_deps="'$state_deps',
    \"sass\": \"^1.72.0\""
else
    css_deps="'$state_deps'"
fi

if [ "$SELECT_TS" = "yes" ]; then
    css_deps="\"typescript\": \"^5.4.5\",
    \"vite-ts-plugin\": \"^1.0.0\",
    $css_deps"
fi

create_file "$PROJECT_DIR/frontend/package.json" "{
  \"name\": \"$PROJECT_NAME\",
  \"private\": true,
  \"version\": \"0.0.0\",
  \"type\": \"module\",
  \"scripts\": {
    \"dev\": \"vite --host 0.0.0.0\",
    \"build\": \"vue-tsc -b && vite build\",
    \"preview\": \"vite preview\"
  },
  \"dependencies\": {
    \"vue\": \"^3.4.27\"
  },
  \"devDependencies\": {
    \"@vitejs/plugin-vue\": \"^5.0.5\",
    \"typescript\": \"^5.4.5\",
    \"vite\": \"^5.3.1\",
    \"vue-tsc\": \"^2.0.21\",
    $css_deps
  }
}
"

# ---- vite.config ----
if [ "$SELECT_TS" = "yes" ]; then
    create_file "$PROJECT_DIR/frontend/vite.config.ts" "import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    port: 3000,
  },
})
"
else
    create_file "$PROJECT_DIR/frontend/vite.config.js" "import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    port: 3000,
  },
})
"
fi

# ---- tsconfig ----
if [ "$SELECT_TS" = "yes" ]; then
    create_file "$PROJECT_DIR/frontend/tsconfig.json" "{
  \"compilerOptions\": {
    \"target\": \"ES2020\",
    \"useDefineForClassFields\": true,
    \"module\": \"ESNext\",
    \"lib\": [\"ES2020\", \"DOM\", \"DOM.Iterable\"],
    \"skipLibCheck\": true,
    \"moduleResolution\": \"bundler\",
    \"allowImportingTsFiles\": true,
    \"isolatedModules\": true,
    \"moduleDetection\": \"force\",
    \"noEmit\": true,
    \"jsx\": \"preserve\",
    \"strict\": true,
    \"noUnusedLocals\": true,
    \"noUnusedParameters\": true,
    \"noFallthroughCasesInSwitch\": true
  },
  \"include\": [\"src/**/*.ts\", \"src/**/*.tsx\", \"src/**/*.vue\"]
}
"
fi

# ---- index.html ----
create_file "$PROJECT_DIR/frontend/index.html" "<!doctype html>
<html lang=\"en\">
  <head>
    <meta charset=\"UTF-8\" />
    <link rel=\"icon\" type=\"image/svg+xml\" href=\"/vite.svg\" />
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />
    <title>${PROJECT_NAME}</title>
  </head>
  <body>
    <div id=\"app\"></div>
    <script type=\"module\" src=\"/src/main.${LANG_EXT}\"></script>
  </body>
</html>
"

# ---- tailwind config ----
if [ "$SELECT_CSS" = "tailwind" ]; then
    if [ "$SELECT_TS" = "yes" ]; then
        create_file "$PROJECT_DIR/frontend/tailwind.config.js" "/** @type {import('tailwindcss').Config} */
export default {
  content: [
    \"./index.html\",
    \"./src/**/*.{vue,js,ts,jsx,tsx}\",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
"
        create_file "$PROJECT_DIR/frontend/postcss.config.js" "export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
"
        create_file "$PROJECT_DIR/frontend/src/style.css" "@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}
"
    else
        create_file "$PROJECT_DIR/frontend/tailwind.config.js" "/** @type {import('tailwindcss').Config} */
export default {
  content: [
    \"./index.html\",
    \"./src/**/*.{vue,js,ts,jsx,tsx}\",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
"
        create_file "$PROJECT_DIR/frontend/postcss.config.js" "export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
"
        create_file "$PROJECT_DIR/frontend/src/style.css" "@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}
"
    fi
fi

# ---- src/main.tsx / main.js ----
if [ "$SELECT_TS" = "yes" ]; then
    state_import=""
    state_setup=""
    if [ "$SELECT_STATE" = "pinia" ]; then
        state_import="import { createPinia } from 'pinia'
"
        state_setup="const pinia = createPinia()
app.use(pinia)
"
    elif [ "$SELECT_STATE" = "vux" ]; then
        state_import="import store from './store'
"
        state_setup="app.use(store)
"
    fi

    create_file "$PROJECT_DIR/frontend/src/main.ts" "import { createApp } from 'vue'
${state_import}import App from './App.vue'
import './style.css'

const app = createApp(App)
${state_setup}
app.mount('#app')
"

    if [ "$SELECT_STATE" = "pinia" ]; then
        create_file "$PROJECT_DIR/frontend/src/stores/counter.ts" "import { defineStore } from 'pinia'

export const useCounterStore = defineStore('counter', {
  state: () => ({ count: 0 }),
  actions: {
    increment() { this.count++ },
    decrement() { this.count-- },
  },
})
"
    elif [ "$SELECT_STATE" = "vux" ]; then
        mkdir -p "$PROJECT_DIR/frontend/src/store"
        create_file "$PROJECT_DIR/frontend/src/store/index.ts" "import { createStore } from 'vuex'

export default createStore({
  state: {
    count: 0,
  },
  mutations: {
    increment(state) { state.count++ },
    decrement(state) { state.count-- },
  },
})
"
    fi

    create_file "$PROJECT_DIR/frontend/src/App.vue" "<script setup lang=\"ts\">
{% if SELECT_STATE == "pinia" %}
import { useCounterStore } from './stores/counter'
{% elif SELECT_STATE == "vux" %}
import { useStore } from 'vuex'
{% endif %}
</script>

<template>
  <div class=\"app\">
    <h1>\${APP_NAME || 'Vue App'}</h1>
{% if SELECT_STATE == "pinia" %}
    <Counter />
{% elif SELECT_STATE == "vux" %}
    <Counter />
{% else %}
    <Counter />
{% endif %}
  </div>
</template>

<style scoped>
.app {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
  text-align: center;
}
</style>
"
else
    # JS version
    create_file "$PROJECT_DIR/frontend/src/main.js" "import { createApp } from 'vue'
import App from './App.vue'
import './style.css'

createApp(App).mount('#app')
"

    create_file "$PROJECT_DIR/frontend/src/App.vue" "<template>
  <div class=\"app\">
    <h1>{{ appName }}</h1>
    <div class=\"counter\">
      <h2>Counter: {{ count }}</h2>
      <button @click=\"count--\">-</button>
      <button @click=\"count++\">+</button>
    </div>
  </div>
</template>

<script>
export default {
  data() {
    return {
      count: 0,
      appName: import.meta.env.VITE_APP_NAME || 'Vue App',
    }
  },
}
</script>

<style scoped>
.app {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
  text-align: center;
}
.counter { margin-top: 2rem; }
.counter button { margin: 0 0.5rem; padding: 0.5rem 1rem; cursor: pointer; }
</style>
"
fi

create_file "$PROJECT_DIR/frontend/src/env.d.ts" "/// <reference types=\"vite/client\" />
"

create_file "$PROJECT_DIR/frontend/.gitignore" "node_modules/
dist/
.env.local
.DS_Store
"

create_file "$PROJECT_DIR/frontend/.dockerignore" "node_modules/
dist/
.env.local
.git/
"

create_file "$PROJECT_DIR/.dockerignore" "frontend/node_modules/
frontend/dist/
node_modules/
.DS_Store
*.log
"

create_file "$PROJECT_DIR/.gitignore" "node_modules/
dist/
.env
.env.local
.DS_Store
*.log
"

create_file "$PROJECT_DIR/start-vue.sh" "#!/bin/bash
set -e

SCRIPT_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd)\"
cd \"\$SCRIPT_DIR\"

if ! command -v docker &> /dev/null; then
    echo \"Error: docker not installed\"
    exit 1
fi

if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD=\"docker compose\"
elif docker-compose --version &> /dev/null 2>&1; then
    COMPOSE_CMD=\"docker-compose\"
else
    echo \"Error: docker-compose not installed\"
    exit 1
fi

echo \"Starting Vue services...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mServices started!\"
echo -e \"Frontend: \033[1;33mhttp://localhost:3000\033[0m\"
echo -e \"Logs:     \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:     \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-vue.sh" "#!/bin/bash
SCRIPT_DIR=\"\$(cd \"\$(dirname \"\${BASH_SOURCE[0]}\")\" && pwd)\"
cd \"\$SCRIPT_DIR\"

if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD=\"docker compose\"
elif docker-compose --version &> /dev/null 2>&1; then
    COMPOSE_CMD=\"docker-compose\"
else
    echo \"Error: docker-compose not installed\"
    exit 1
fi

echo \"Stopping Vue services...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

chmod +x "$PROJECT_DIR/start-vue.sh"
chmod +x "$PROJECT_DIR/stop-vue.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Vue project created successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Features selected:"
echo -e "  TypeScript:   ${YELLOW}$SELECT_TS${NC}"
echo -e "  CSS:          ${YELLOW}$SELECT_CSS${NC}"
echo -e "  State Mgmt:   ${YELLOW}$SELECT_STATE${NC}"
echo ""
echo -e "Location: ${YELLOW}$PROJECT_DIR${NC}"
echo ""
echo -e "${GREEN}Next steps:${NC}"
echo "1. cd $PROJECT_NAME/frontend"
echo "2. npm install"
echo "3. npm run dev"
echo "4. Open http://localhost:3000"
echo ""
