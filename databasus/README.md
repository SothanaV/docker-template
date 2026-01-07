# 🚀 Databasus

**Databasus** is a lightweight database service platform that allows you to easily spin up and manage your data environment using Docker Compose.

---

## 📦 Requirements

- Docker  
- Docker Compose  

Check installation:

```bash
docker --version
docker compose version
```

---

## 🛠️ Installation & Run

Clone repository

Start services:

```bash
docker compose up
```

Start full
```
docker compose -f full.yml up
```

---

## 🌐 Access Application

Open browser:

```
http://localhost:4005
```

---

## 🧭 Following Steps

1. Add datastore
2. Add database
3. view backup logs




## 🐞 Troubleshooting

| Problem | Solution |
|-------|----------|
| Port 4005 already in use | Stop the service using this port or change it in `docker-compose.yml` |
| Containers not starting | Check logs using `docker compose logs` |
| UI not accessible | Make sure containers are healthy in `docker ps` |

---

## 📜 License

MIT License