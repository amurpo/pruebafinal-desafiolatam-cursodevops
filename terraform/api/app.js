const http = require('http');
const port = 3000;

const server = http.createServer((req, res) => {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'text/plain');
    res.end('¡Hola  a todos en el curso devops con Node.js!');
});

server.listen(port, () => {
    console.log(`Servidor ejecutándose en http://localhost:${port}`);
});