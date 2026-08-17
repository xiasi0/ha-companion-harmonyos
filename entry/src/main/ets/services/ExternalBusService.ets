// Parses and responds to Home Assistant frontend externalBus messages.
// This service is used outside the dashboard feature, so keep bridge protocol logic stable here.
import { AppVersionService } from './AppVersionService';

export class ExternalBusService {
  static parsePayload(payload: Object | string): Record<string, Object | string | number | boolean> {
    if (typeof payload === 'string') {
      try {
        return JSON.parse(payload) as Record<string, Object | string | number | boolean>;
      } catch (_) {
        return {};
      }
    }
    return payload as Record<string, Object | string | number | boolean>;
  }

  static callbackName(payload: Object | string): string {
    const parsed = ExternalBusService.parsePayload(payload);
    const raw = parsed['callback'];
    return typeof raw === 'string' ? raw : '';
  }

  static forceRefresh(payload: Object | string): boolean {
    const parsed = ExternalBusService.parsePayload(payload);
    const raw = parsed['force'];
    return raw === true || raw === 'true' || raw === '1';
  }

  static type(payload: Object | string): string {
    const parsed = ExternalBusService.parsePayload(payload);
    const raw = parsed['type'];
    return typeof raw === 'string' ? raw : '';
  }

  static id(payload: Object | string): number {
    const parsed = ExternalBusService.parsePayload(payload);
    const raw = parsed['id'];
    if (typeof raw === 'number') {
      return raw;
    }
    if (typeof raw === 'string') {
      const id = Number(raw);
      return Number.isFinite(id) ? id : -1;
    }
    return -1;
  }

  static payload(payload: Object | string): Record<string, Object | string | number | boolean> {
    const parsed = ExternalBusService.parsePayload(payload);
    const raw = parsed['payload'];
    if (raw && typeof raw === 'object') {
      return raw as Record<string, Object | string | number | boolean>;
    }
    return {};
  }

  static booleanPayload(payload: Object | string, key: string, defaultValue: boolean): boolean {
    const parsed = ExternalBusService.payload(payload);
    const raw = parsed[key];
    if (typeof raw === 'boolean') {
      return raw;
    }
    if (typeof raw === 'string') {
      return raw === 'true' || raw === '1';
    }
    return defaultValue;
  }

  static stringPayload(payload: Object | string, key: string, defaultValue: string): string {
    const parsed = ExternalBusService.payload(payload);
    const raw = parsed[key];
    return typeof raw === 'string' && raw.length > 0 ? raw : defaultValue;
  }

  static isServerCommandType(type: string): boolean {
    return type === 'haptic' ||
      type === 'tag/write' ||
      type === 'matter/commission' ||
      type === 'thread/import_credentials' ||
      type === 'download/file' ||
      type === 'scan_barcode';
  }

  static buildExternalAuthCallbackScript(
    callback: string,
    success: boolean,
    token: string = '',
    expiresIn: number = 0
  ): string {
    const safeCallback = ExternalBusService.jsQuoted(callback);
    const safeToken = ExternalBusService.jsQuoted(token);
    const safeExpiresIn = Number.isFinite(expiresIn) && expiresIn > 0 ? Math.ceil(expiresIn) : 0;
    return success
      ? `(function(){var fn=window['${safeCallback}'];if(typeof fn==='function'){fn(true,{access_token:'${safeToken}',expires_in:${safeExpiresIn}});}})();`
      : `(function(){var fn=window['${safeCallback}'];if(typeof fn==='function'){fn(false);}})();`;
  }

  static buildConfigResponseScript(messageId: number): string {
    const id = messageId >= 0 ? messageId : 0;
    const json = `{"type":"result","id":${id},"success":true,"result":{"hasSettingsScreen":true,"canWriteTag":false,"hasExoPlayer":true,"canCommissionMatter":false,"canImportThreadCredentials":false,"hasAssist":true,"hasBarCodeScanner":0,"canSetupImprov":false,"downloadFileSupported":false,"appVersion":${AppVersionService.versionNameJson()},"hasEntityAddTo":false,"hasAssistSettings":true},"error":null}`;
    return `(function(){if(typeof externalBus==='function'){externalBus(${json});}else if(typeof window.externalBus==='function'){window.externalBus(${json});}})();`;
  }

  private static jsQuoted(value: string): string {
    return value.replace(/\\/g, '\\\\').replace(/'/g, '\\\'').replace(/\r/g, '').replace(/\n/g, '\\n');
  }
}
