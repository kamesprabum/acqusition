import express from 'express';
const app = express();

app.get('/', (req, res) => {
  res.status(200).send(`
        <h1 style="font-family: Helvatica;">
          hello from bruo!
        </h1>
      `);
});

export default app;
