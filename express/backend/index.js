
const express = require('express')
const cors = require('cors')
const app = express()
const port = 3000


console.log(process.env)

app.use(cors())
app.use(express.json());

app.get('/', (req, res) => {
  res.send('Hello World!')
})

app.get('/healthz', async (req, res) => {
    const status = { status: 'healthy', service: 'express' };
    let statusCode = 200;

    // Check PostgreSQL
    try {
        const { Client } = require('pg');
        const client = new Client(process.env.DATABASE_URL);
        await client.connect();
        await client.query('SELECT 1');
        await client.end();
        status.postgreSQL = 'connected';
    } catch (err) {
        status.postgreSQL = 'disconnected';
        status.status = 'degraded';
    }

    // Check Redis
    try {
        const redis = require('redis');
        const pubClient = redis.createClient({ url: process.env.REDIS_URL || 'redis://localhost:6379' });
        await pubClient.connect();
        await pubClient.ping();
        await pubClient.quit();
        status.redis = 'connected';
    } catch (err) {
        status.redis = 'disconnected';
        status.status = 'degraded';
    }

    if (status.status !== 'healthy') {
        statusCode = 503;
    }
    res.status(statusCode).json(status);
});

app.listen(port, () => {
  console.log()
}) 
