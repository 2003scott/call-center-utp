import express, { Request, Response } from 'express';
import cors from 'cors';
import {
    conectarAsterisk,
    colgarLlamada,
    getEstadoAsterisk,
    originarLlamada
} from './services/asterisk';


const app = express();
const port = Number(process.env.PORT || 3000);

app.use(express.json());
app.use(cors());

app.post('/api/llamadas/iniciar', async (req: Request, res: Response) => {
    const { origen, destino } = req.body;
    
    if (!origen || !destino) {
        return res.status(400).json({ error: "Faltan los parámetros obligatorios: 'origen' y 'destino'." });
    }

    try {
        const llamada = await originarLlamada(origen.toString(), destino.toString());
        
        return res.json({ 
            mensaje: "La orden de llamada fue enviada con éxito al motor de telefonía.",
            estado: llamada.estado,
            llamada
        });
    } catch (error: any) {
        return res.status(500).json({ 
            error: "El orquestador no pudo procesar la llamada.",
            detalles: error.message 
        });
    }
});

app.get('/api/health', (req: Request, res: Response) => {
    res.json({ estado: "El Orquestador está funcionando", asterisk: getEstadoAsterisk() });
});

app.get('/api/llamadas/estado', (req: Request, res: Response) => {
    res.json(getEstadoAsterisk());
});

app.listen(port, async () => {
    console.log("🚀 Servidor HTTP de la API listo.");
    conectarAsterisk().catch((error: any) => {
        console.error('⚠️ Asterisk no quedó disponible al arranque:', error.message || error);
    });
});

app.post('/api/llamadas/colgar', async (req: Request, res: Response) => {
    const { canalId } = req.body;
    
    if (!canalId) {
        return res.status(400).json({ error: "Falta el parámetro 'canalId'." });
    }

    try {
        await colgarLlamada(canalId.toString());
        return res.json({ mensaje: "Orden de colgar procesada." });
    } catch (error: any) {
        return res.status(500).json({ error: "No se pudo colgar la llamada." });
    }
});