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
    echo "Example: $0 my-react-app"
    exit 1
fi

PROJECT_NAME="$1"
PROJECT_DIR="$(pwd)/$PROJECT_NAME"

echo -e "${GREEN}Creating React project: $PROJECT_NAME${NC}"
echo "Target directory: $PROJECT_DIR"

echo -e "\n${CYAN}══════════════════════════════════════════${NC}"
echo -e "${CYAN}   React Project Features${NC}"
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

echo -e "\n${YELLOW}Select CSS approach:${NC}"
echo "  1) Tailwind CSS (default)"
echo "  2) CSS Modules"
echo "  3) Vanilla CSS"
read -p "  Enter choice [1]: " css_choice
css_choice="${css_choice:-1}"
case $css_choice in
    1) SELECT_CSS="tailwind" ;;
    2) SELECT_CSS="modules" ;;
    3) SELECT_CSS="vanilla" ;;
esac

echo -e "\n${YELLOW}Select state management:${NC}"
echo "  1) React Context (default)"
echo "  2) Redux Toolkit"
echo "  3) Zustand"
read -p "  Enter choice [1]: " state_choice
state_choice="${state_choice:-1}"
case $state_choice in
    1) SELECT_STATE="context" ;;
    2) SELECT_STATE="redux" ;;
    3) SELECT_STATE="zustand" ;;
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

# Build docker-compose for frontend only
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
if [ "$SELECT_TS" = "yes" ]; then
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
else
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
fi

# ---- Nginx config for frontend ----
create_file "$PROJECT_DIR/frontend/nginx.conf" "server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api {
        proxy_pass http://backend:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
"

# ---- Package.json ----
if [ "$SELECT_TS" = "yes" ]; then
    if [ "$SELECT_CSS" = "tailwind" ]; then
        create_file "$PROJECT_DIR/frontend/package.json" "{
  \"name\": \"$PROJECT_NAME\",
  \"private\": true,
  \"version\": \"0.0.0\",
  \"type\": \"module\",
  \"scripts\": {
    \"dev\": \"vite --host 0.0.0.0\",
    \"build\": \"tsc -b && vite build\",
    \"preview\": \"vite preview\"
  },
  \"dependencies\": {
    \"react\": \"^18.3.1\",
    \"react-dom\": \"^18.3.1\"
  },
  \"devDependencies\": {
    \"@types/react\": \"^18.3.3\",
    \"@types/react-dom\": \"^18.3.0\",
    \"@vitejs/plugin-react\": \"^4.3.1\",
    \"autoprefixer\": \"^10.4.19\",
    \"postcss\": \"^8.4.38\",
    \"tailwindcss\": \"^3.4.4\",
    \"typescript\": \"^5.4.5\",
    \"vite\": \"^5.3.1\"
  }
}
"
    elif [ "$SELECT_STATE" = "redux" ]; then
        create_file "$PROJECT_DIR/frontend/package.json" "{
  \"name\": \"$PROJECT_NAME\",
  \"private\": true,
  \"version\": \"0.0.0\",
  \"type\": \"module\",
  \"scripts\": {
    \"dev\": \"vite --host 0.0.0.0\",
    \"build\": \"tsc -b && vite build\",
    \"preview\": \"vite preview\"
  },
  \"dependencies\": {
    \"react\": \"^18.3.1\",
    \"react-dom\": \"^18.3.1\",
    \"@reduxjs/toolkit\": \"^2.2.5\",
    \"react-redux\": \"^9.1.2\"
  },
  \"devDependencies\": {
    \"@types/react\": \"^18.3.3\",
    \"@types/react-dom\": \"^18.3.0\",
    \"@vitejs/plugin-react\": \"^4.3.1\",
    \"typescript\": \"^5.4.5\",
    \"vite\": \"^5.3.1\"
  }
}
"
    elif [ "$SELECT_STATE" = "zustand" ]; then
        create_file "$PROJECT_DIR/frontend/package.json" "{
  \"name\": \"$PROJECT_NAME\",
  \"private\": true,
  \"version\": \"0.0.0\",
  \"type\": \"module\",
  \"scripts\": {
    \"dev\": \"vite --host 0.0.0.0\",
    \"build\": \"tsc -b && vite build\",
    \"preview\": \"vite preview\"
  },
  \"dependencies\": {
    \"react\": \"^18.3.1\",
    \"react-dom\": \"^18.3.1\",
    \"zustand\": \"^4.5.2\"
  },
  \"devDependencies\": {
    \"@types/react\": \"^18.3.3\",
    \"@types/react-dom\": \"^18.3.0\",
    \"@vitejs/plugin-react\": \"^4.3.1\",
    \"typescript\": \"^5.4.5\",
    \"vite\": \"^5.3.1\"
  }
}
"
    else
        create_file "$PROJECT_DIR/frontend/package.json" "{
  \"name\": \"$PROJECT_NAME\",
  \"private\": true,
  \"version\": \"0.0.0\",
  \"type\": \"module\",
  \"scripts\": {
    \"dev\": \"vite --host 0.0.0.0\",
    \"build\": \"tsc -b && vite build\",
    \"preview\": \"vite preview\"
  },
  \"dependencies\": {
    \"react\": \"^18.3.1\",
    \"react-dom\": \"^18.3.1\"
  },
  \"devDependencies\": {
    \"@types/react\": \"^18.3.3\",
    \"@types/react-dom\": \"^18.3.0\",
    \"@vitejs/plugin-react\": \"^4.3.1\",
    \"typescript\": \"^5.4.5\",
    \"vite\": \"^5.3.1\"
  }
}
"
    fi
else
    create_file "$PROJECT_DIR/frontend/package.json" "{
  \"name\": \"$PROJECT_NAME\",
  \"private\": true,
  \"version\": \"0.0.0\",
  \"type\": \"module\",
  \"scripts\": {
    \"dev\": \"vite --host 0.0.0.0\",
    \"build\": \"vite build\",
    \"preview\": \"vite preview\"
  },
  \"dependencies\": {
    \"react\": \"^18.3.1\",
    \"react-dom\": \"^18.3.1\"
  },
  \"devDependencies\": {
    \"@vitejs/plugin-react\": \"^4.3.1\",
    \"vite\": \"^5.3.1\"
  }
}
"
fi

# ---- vite.config ----
if [ "$SELECT_CSS" = "tailwind" ]; then
    if [ "$SELECT_TS" = "yes" ]; then
        create_file "$PROJECT_DIR/frontend/vite.config.ts" "import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
  },
})
"
    else
        create_file "$PROJECT_DIR/frontend/vite.config.js" "import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
  },
})
"
    fi
else
    if [ "$SELECT_TS" = "yes" ]; then
        create_file "$PROJECT_DIR/frontend/vite.config.ts" "import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
  },
})
"
    else
        create_file "$PROJECT_DIR/frontend/vite.config.js" "import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
  },
})
"
    fi
fi

# ---- tsconfig ----
if [ "$SELECT_TS" = "yes" ]; then
    create_file "$PROJECT_DIR/frontend/tsconfig.json" "{
  \"compilerOptions\": {
    \"target\": \"ES2020\",
    \"useDefineForClassFields\": true,
    \"lib\": [\"ES2020\", \"DOM\", \"DOM.Iterable\"],
    \"module\": \"ESNext\",
    \"skipLibCheck\": true,
    \"moduleResolution\": \"bundler\",
    \"allowImportingTsFiles\": true,
    \"isolatedModules\": true,
    \"moduleDetection\": \"force\",
    \"noEmit\": true,
    \"jsx\": \"react-jsx\",
    \"strict\": true,
    \"noUnusedLocals\": true,
    \"noUnusedParameters\": true,
    \"noFallthroughCasesInSwitch\": true
  },
  \"include\": [\"src\"]
}
"

    create_file "$PROJECT_DIR/frontend/tsconfig.app.json" "{
  \"compilerOptions\": {
    \"composite\": true,
    \"tsBuildInfoFile\": \"./node_modules/.tmp/tsconfig.app.tsbuildinfo\",
    \"target\": \"ES2020\",
    \"useDefineForClassFields\": true,
    \"lib\": [\"ES2020\", \"DOM\", \"DOM.Iterable\"],
    \"module\": \"ESNext\",
    \"skipLibCheck\": true,
    \"moduleResolution\": \"bundler\",
    \"allowImportingTsFiles\": true,
    \"isolatedModules\": true,
    \"moduleDetection\": \"force\",
    \"noEmit\": true,
    \"jsx\": \"react-jsx\",
    \"strict\": true,
    \"noUnusedLocals\": true,
    \"noUnusedParameters\": true,
    \"noFallthroughCasesInSwitch\": true
  },
  \"include\": [\"src\"]
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
    <div id=\"root\"></div>
    <script type=\"module\" src=\"/src/main.${LANG_EXT}\"></script>
  </body>
</html>
"

# ---- tailwind.config if selected ----
if [ "$SELECT_CSS" = "tailwind" ]; then
    if [ "$SELECT_TS" = "yes" ]; then
        create_file "$PROJECT_DIR/frontend/tailwind.config.js" "/** @type {import('tailwindcss').Config} */
export default {
  content: [
    \"./index.html\",
    \"./src/**/*.{js,ts,jsx,tsx}\",
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
    fi
fi

# ---- src/index.css ----
if [ "$SELECT_CSS" = "tailwind" ]; then
    if [ "$SELECT_TS" = "yes" ]; then
        create_file "$PROJECT_DIR/frontend/src/index.css" "@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}
"
    else
        create_file "$PROJECT_DIR/frontend/src/index.css" "@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}
"
    fi
elif [ "$SELECT_CSS" = "modules" ]; then
    create_file "$PROJECT_DIR/frontend/src/app.module.css" ".app {
  padding: 2rem;
  text-align: center;
}
"
else
    create_file "$PROJECT_DIR/frontend/src/index.css" "body {
  margin: 0;
  padding: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

* {
  box-sizing: border-box;
}
"
fi

# ---- src/main.tsx / main.js ----
if [ "$SELECT_TS" = "yes" ]; then
    create_file "$PROJECT_DIR/frontend/src/main.tsx" "import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
"
    if [ "$SELECT_STATE" = "context" ]; then
        create_file "$PROJECT_DIR/frontend/src/App.tsx" "import { useState, createContext, useContext } from 'react'
import './App.css'

const AppContext = createContext<{ count: number; setCount: (n: number) => void } | null>(null)

function AppProvider({ children }: { children: React.ReactNode }) {
  const [count, setCount] = useState(0)
  return (
    <AppContext.Provider value={{ count, setCount }}>
      {children}
    </AppContext.Provider>
  )
}

function useAppContext() {
  const ctx = useContext(AppContext)
  if (!ctx) throw new Error('useAppContext must be used within AppProvider')
  return ctx
}

function Counter() {
  const { count, setCount } = useAppContext()
  return (
    <div className=\"counter\">
      <h2>Counter: {count}</h2>
      <button onClick={() => setCount(c => c + 1)}>+</button>
      <button onClick={() => setCount(c => c - 1)}>-</button>
    </div>
  )
}

function App() {
  const [message] = useState('Welcome to ' + (import.meta.env.VITE_APP_NAME || 'React App'))
  return (
    <AppProvider>
      <div className=\"app\">
        <h1>{message}</h1>
        <Counter />
      </div>
    </AppProvider>
  )
}

export default App
"
    elif [ "$SELECT_STATE" = "redux" ]; then
        create_file "$PROJECT_DIR/frontend/src/App.tsx" "import { Provider } from 'react-redux'
import { configureStore, createSlice, PayloadAction } from '@reduxjs/toolkit'
import './App.css'

interface CounterState {
  value: number
}

const counterSlice = createSlice({
  name: 'counter',
  initialState: { value: 0 } as CounterState,
  reducers: {
    incremented: (state) => { state.value += 1 },
    decremented: (state) => { state.value -= 1 },
  },
})

const store = configureStore({ reducer: { counter: counterSlice.reducer } })

function App() {
  return (
    <Provider store={store}>
      <div className=\"app\">
        <h1>Welcome to {import.meta.env.VITE_APP_NAME || 'React App'}</h1>
        <Counter />
      </div>
    </Provider>
  )
}

function Counter() {
  const count = 0
  return <div className=\"counter\"><h2>Counter: {count}</h2></div>
}

export { store }
export default App
"
    elif [ "$SELECT_STATE" = "zustand" ]; then
        create_file "$PROJECT_DIR/frontend/src/stores/store.ts" "import { create } from 'zustand'

interface AppState {
  count: number
  increment: () => void
  decrement: () => void
}

export const useStore = create<AppState>((set) => ({
  count: 0,
  increment: () => set((state) => ({ count: state.count + 1 })),
  decrement: () => set((state) => ({ count: state.count - 1 })),
}))
"
        create_file "$PROJECT_DIR/frontend/src/App.tsx" "import { useStore } from './stores/store'
import './App.css'

function App() {
  return (
    <div className=\"app\">
      <h1>Welcome to {import.meta.env.VITE_APP_NAME || 'React App'}</h1>
      <Counter />
    </div>
  )
}

function Counter() {
  const { count, increment, decrement } = useStore()
  return (
    <div className=\"counter\">
      <h2>Counter: {count}</h2>
      <button onClick={increment}>+</button>
      <button onClick={decrement}>-</button>
    </div>
  )
}

export default App
"
    else
        create_file "$PROJECT_DIR/frontend/src/App.tsx" "import { useState } from 'react'
import './App.css'

function App() {
  const [count, setCount] = useState(0)
  return (
    <div className=\"app\">
      <h1>Welcome to {import.meta.env.VITE_APP_NAME || 'React App'}</h1>
      <div className=\"counter\">
        <h2>Counter: {count}</h2>
        <button onClick={() => setCount(c => c + 1)}>+</button>
        <button onClick={() => setCount(c => c - 1)}>-</button>
      </div>
    </div>
  )
}

export default App
"
    fi
else
    # JavaScript version
    create_file "$PROJECT_DIR/frontend/src/main.js" "import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
"

    create_file "$PROJECT_DIR/frontend/src/App.js" "import { useState } from 'react'
import './App.css'

function App() {
  const [count, setCount] = useState(0)
  return (
    <div className=\"app\">
      <h1>Welcome to {process.env.VITE_APP_NAME || 'React App'}</h1>
      <div className=\"counter\">
        <h2>Counter: {count}</h2>
        <button onClick={() => setCount(c => c + 1)}>+</button>
        <button onClick={() => setCount(c => c - 1)}>-</button>
      </div>
    </div>
  )
}

export default App
"
fi

# ---- App.css ----
create_file "$PROJECT_DIR/frontend/src/App.css" ".app {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
  text-align: center;
}

h1 {
  color: #333;
}

.counter {
  margin-top: 2rem;
}

.counter button {
  margin: 0 0.5rem;
  padding: 0.5rem 1rem;
  font-size: 1.2rem;
  cursor: pointer;
}
"

# ---- .env ----
create_file "$PROJECT_DIR/frontend/.env.local" "# VITE_API_URL=http://localhost:5050/api
# Add your env vars here
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
backend/node_modules/
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

create_file "$PROJECT_DIR/start-react.sh" "#!/bin/bash
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

echo \"Starting React services...\"
\$COMPOSE_CMD down 2>/dev/null || true
\$COMPOSE_CMD up --build -d
echo \"\"
echo -e \"\033[0;32mServices started!\"
echo -e \"Frontend: \033[1;33mhttp://localhost:3000\033[0m\"
echo -e \"Logs:     \033[1;33m\$COMPOSE_CMD logs -f\033[0m\"
echo -e \"Stop:     \033[1;33m\$COMPOSE_CMD down\033[0m\"
"

create_file "$PROJECT_DIR/stop-react.sh" "#!/bin/bash
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

echo \"Stopping React services...\"
\$COMPOSE_CMD down
echo \"Services stopped!\"
"

chmod +x "$PROJECT_DIR/start-react.sh"
chmod +x "$PROJECT_DIR/stop-react.sh"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}React project created successfully!${NC}"
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
