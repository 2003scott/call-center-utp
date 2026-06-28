type AsteriskConfig = {
    ariUrl: string;
    ariUser: string;
    ariPassword: string;
    appName: string;
};

const readEnv = (name: string, fallback: string) => {
    const value = process.env[name];
    return value && value.trim().length > 0 ? value : fallback;
};

export const getAsteriskConfig = (): AsteriskConfig => ({
    ariUrl: readEnv('ASTERISK_ARI_URL', 'http://asterisk_pbx:8088'),
    ariUser: readEnv('ASTERISK_ARI_USER', 'orquestador_user'),
    ariPassword: readEnv('ASTERISK_ARI_PASSWORD', 'clave_secreta_123'),
    appName: readEnv('ASTERISK_APP_NAME', 'orquestador_app')
});