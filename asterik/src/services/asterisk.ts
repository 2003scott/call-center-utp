const ari: any = require('ari-client');
import { getAsteriskConfig } from '../config';

type CallStatus = 'creada' | 'sonando' | 'puenteada' | 'cerrada' | 'fallida';

type CallSession = {
    callId: string;
    origen: string;
    destino: string;
    estado: CallStatus;
    agentChannelId?: string;
    customerChannelId?: string;
    bridgeId?: string;
    createdAt: string;
    updatedAt: string;
    lastError?: string;
};

let asteriskClient: any = null;
let stasisHandlersRegistered = false;
const activeCalls = new Map<string, CallSession>();

const touchCall = (callId: string, patch: Partial<CallSession>) => {
    const current = activeCalls.get(callId);
    if (!current) {
        return;
    }

    activeCalls.set(callId, {
        ...current,
        ...patch,
        updatedAt: new Date().toISOString()
    });
};

const registerEventHandlers = () => {
    if (!asteriskClient || stasisHandlersRegistered) {
        return;
    }

    asteriskClient.on('StasisStart', async (event: any, channel: any) => {
        const callId = event?.args?.[0];
        if (!callId || !activeCalls.has(callId)) {
            return;
        }

        const session = activeCalls.get(callId);
        if (!session) {
            return;
        }

        try {
            if (!session.agentChannelId || session.agentChannelId === channel.id) {
                session.agentChannelId = channel.id;
                session.estado = 'sonando';
                session.updatedAt = new Date().toISOString();
                activeCalls.set(callId, session);

                await channel.answer();

                const bridge = await asteriskClient.bridges.create({ type: 'mixing' });
                session.bridgeId = bridge.id;
                await bridge.addChannel({ channel: channel.id });

                const customerChannel = await asteriskClient.channels.originate({
                    endpoint: `PJSIP/${session.destino}`,
                    app: getAsteriskConfig().appName,
                    appArgs: callId,
                    callerId: session.origen
                });

                session.customerChannelId = customerChannel?.id;
                session.updatedAt = new Date().toISOString();
                activeCalls.set(callId, session);
                return;
            }

            if (!session.customerChannelId || session.customerChannelId === channel.id) {
                session.customerChannelId = channel.id;
                session.estado = 'puenteada';
                session.updatedAt = new Date().toISOString();
                activeCalls.set(callId, session);

                await channel.answer();

                if (session.bridgeId) {
                    const bridge = asteriskClient.bridges.get({ bridgeId: session.bridgeId });
                    await bridge.addChannel({ channel: channel.id });
                }
            }
        } catch (error: any) {
            session.estado = 'fallida';
            session.lastError = error.message || String(error);
            session.updatedAt = new Date().toISOString();
            activeCalls.set(callId, session);
            console.error('❌ Error manejando StasisStart:', error.message || error);
        }
    });

    const markClosed = (channelId: string) => {
        for (const [callId, session] of activeCalls.entries()) {
            if (session.agentChannelId === channelId || session.customerChannelId === channelId) {
                touchCall(callId, { estado: 'cerrada' });
            }
        }
    };

    asteriskClient.on('StasisEnd', (_event: any, channel: any) => {
        markClosed(channel.id);
    });

    asteriskClient.on('ChannelDestroyed', (event: any) => {
        markClosed(event?.channel?.id);
    });

    stasisHandlersRegistered = true;
};

export const conectarAsterisk = async () => {
    const { ariUrl, ariUser, ariPassword, appName } = getAsteriskConfig();

    if (asteriskClient) {
        registerEventHandlers();
        return asteriskClient;
    }

    try {
        console.log('⏳ Intentando conectar al motor Asterisk...');

        asteriskClient = await ari.connect(ariUrl, ariUser, ariPassword);
        registerEventHandlers();
        asteriskClient.start(appName);

        console.log('✅ ¡Conexión exitosa a Asterisk!');
        return asteriskClient;
    } catch (error: any) {
        console.error('❌ Error al conectar con Asterisk:', error.message || error);
        asteriskClient = null;
        throw error;
    }
};

export const originarLlamada = async (origen: string, destino: string) => {
    await conectarAsterisk();

    if (!asteriskClient) {
        throw new Error('El motor Asterisk no está conectado todavía.');
    }

    console.log(`📞 [Orquestador] Solicitando llamada: ${origen} -> ${destino}`);

    const callId = `call-${Date.now()}-${Math.random().toString(16).slice(2, 10)}`;
    const session: CallSession = {
        callId,
        origen,
        destino,
        estado: 'creada',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
    };

    activeCalls.set(callId, session);

    try {
        const agentChannel = await asteriskClient.channels.originate({
            endpoint: `PJSIP/${origen}`,
            app: getAsteriskConfig().appName,
            appArgs: callId,
            callerId: origen
        });

        session.agentChannelId = agentChannel?.id;
        session.estado = 'sonando';
        session.updatedAt = new Date().toISOString();
        activeCalls.set(callId, session);

        return session;
    } catch (error: any) {
        console.error('❌ Error de ARI al originar canal:', error.message || error);
        session.estado = 'fallida';
        session.lastError = error.message || String(error);
        session.updatedAt = new Date().toISOString();
        activeCalls.set(callId, session);
        throw error;
    }
};

export const getEstadoAsterisk = () => ({
    conectado: Boolean(asteriskClient),
    appName: getAsteriskConfig().appName,
    llamadasActivas: Array.from(activeCalls.values())
});

export const colgarLlamada = async (canalId: string) => {
    await conectarAsterisk();

    if (!asteriskClient) {
        throw new Error('El motor Asterisk no está conectado.');
    }

    console.log(`✂️ [Orquestador] Cortando llamada en el canal: ${canalId}`);

    try {
        await asteriskClient.channels.hangup({ channelId: canalId });
        console.log('✅ Llamada colgada exitosamente.');
    } catch (error: any) {
        console.error('❌ Error al intentar colgar:', error.message || error);
        throw error;
    }
};