import express from "express";
import logger from "./config/logger.js";
import morgan from "morgan";
import cors from "cors";
import cookieParser from "cookie-parser";
import helmet from "helmet";

import authRoutes from "./routes/auth.routes.js";

const app = express();

app.use(cors());
app.use(cookieParser());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use(
  morgan("combined", {
    stream: {
      write: (message) => logger.info(message.trim()),
    },
  })
);

app.use(helmet());

app.get("/", (req, res) => {
  logger.info("Hello from acquisition!");

  res.status(200).send(`
    <h1 style="font-family: Helvetica;">
      hello from bruo!
    </h1>
  `);
});

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "ok",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

app.get("/healthz", (req, res) => {
  res.status(200).json({
    message: "Acquisition API is healthy",
  });
});

app.use("/api/auth", authRoutes);

export default app;