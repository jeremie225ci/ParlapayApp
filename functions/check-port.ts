// Este es un script de prueba para verificar la configuración del puerto
import express from 'express';

const app = express();

app.get('/', (req, res) => {
  res.send('¡El servidor está funcionando correctamente!');
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`Servidor de prueba escuchando en el puerto ${PORT}`);
  console.log(`Variables de entorno disponibles:`);
  console.log(`- PORT: ${process.env.PORT}`);
  console.log(`- NODE_ENV: ${process.env.NODE_ENV}`);
});