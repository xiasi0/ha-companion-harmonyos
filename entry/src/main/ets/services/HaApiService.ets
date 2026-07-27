// Home Assistant REST and WebSocket client surface used by the app features.
// Keep Home Assistant wire-format keys stable here because release obfuscation can rename properties.
import { NetworkHttpMethod, NetworkService, NetworkWebSocket } from './NetworkService';
import { HaConfigInfo } from '../models/HaConfigInfo';
import { Localization } from '../shared/i18n/Localization';
import { HaAssistApiService } from './HaAssistApiService';
import { HaEntityParser } from './HaEntityParser';
import {
  HaAssistPipelineRunResult,
  HaCameraEntity,
  HaRegistryCatalog,
  HaConversationAgent,
  HaConversationAgentsResult,
  HaConfigFetchResult,
  HaEntityCatalogResult,
  HaLightActionResult,
  HaLightEntitiesResult,
  HaLightEntity,
  HaMediaPlayerEntitiesResult,
  HaMediaPlayerEntity,
  HaMobileAppRegistrationInfo,
  HaMobileAppRegistrationRequest,
  HaMobileAppRegistrationResult
} from './HaApiModels';

export {
  HaAssistPipelineRunResult,
  HaCameraEntity,
  HaBindableEntity,
  HaConversationAgent,
  HaConversationAgentsResult,
  HaConfigFetchResult,
  HaEntityCatalogItem,
  HaEntityCatalogResult,
  HaLightActionResult,
  HaLightEntitiesResult,
  HaLightEntity,
  HaMediaPlayerEntitiesResult,
  HaMediaPlayerEntity,
  HaMobileAppRegistrationInfo,
  HaMobileAppRegistrationRequest,
  HaMobileAppRegistrationResult
} from './HaApiModels';

export class HaApiService {
  static async updateCoreLocationName(baseUrl: string, accessToken: string, locationName: string): Promise<void> {
    await HaApiService.withAuthenticatedWebSocket(baseUrl, accessToken,
      async (client, nextId): Promise<void> => {
        await HaApiService.sendWebSocketCommand(client, nextId(), {
          'type': 'config/core/update',
          'location_name': locationName
        });
      });
  }

  static async fetchLightEntities(baseUrl: string, accessToken: string): Promise<HaLightEntitiesResult> {
    try {
      const resp = await NetworkService.requestText(`${baseUrl}/api/states`, {
        method: NetworkHttpMethod.GET,
        header: {
          'Authorization': `Bearer ${accessToken}`
        },
        connectTimeout: 12000,
        readTimeout: 12000
      });
      const body = resp.body;
      if (resp.responseCode < 200 || resp.responseCode >= 300) {
        return {
          responseCode: resp.responseCode,
          entities: [],
          failureSummary: Localization.format2('ha_error_fetch_lights_http',
            'status', resp.responseCode, 'detail', NetworkService.shortText(body))
        };
      }
      return {
        responseCode: resp.responseCode,
        entities: HaEntityParser.parseLightEntities(body),
        failureSummary: ''
      };
    } catch (err) {
      return {
        responseCode: 0,
        entities: [],
        failureSummary: NetworkService.errorText(err as Error | string | number | boolean)
      };
    }
  }

  static async fetchEntityCatalog(baseUrl: string, accessToken: string): Promise<HaEntityCatalogResult> {
    try {
      const resp = await NetworkService.requestText(`${baseUrl}/api/states`, {
        method: NetworkHttpMethod.GET,
        header: {
          'Authorization': `Bearer ${accessToken}`
        },
        connectTimeout: 12000,
        readTimeout: 12000
      });
      const body = resp.body;
      if (resp.responseCode < 200 || resp.responseCode >= 300) {
        return {
          responseCode: resp.responseCode,
          entities: [],
          failureSummary: NetworkService.shortText(body)
        };
      }
      return {
        responseCode: resp.responseCode,
        entities: HaEntityParser.mergeEntityCatalog(
          HaEntityParser.parseEntityCatalog(body),
          await HaApiService.fetchRegistryCatalog(baseUrl, accessToken)
        ),
        failureSummary: ''
      };
    } catch (err) {
      return {
        responseCode: 0,
        entities: [],
        failureSummary: NetworkService.errorText(err as Error | string | number | boolean)
      };
    }
  }

  static async fetchMediaPlayerEntities(baseUrl: string, accessToken: string): Promise<HaMediaPlayerEntitiesResult> {
    try {
      const resp = await NetworkService.requestText(`${baseUrl}/api/states`, {
        method: NetworkHttpMethod.GET,
        header: {
          'Authorization': `Bearer ${accessToken}`
        },
        connectTimeout: 12000,
        readTimeout: 12000
      });
      const body = resp.body;
      if (resp.responseCode < 200 || resp.responseCode >= 300) {
        return {
          responseCode: resp.responseCode,
          entities: [],
          failureSummary: Localization.format2('ha_error_fetch_media_http',
            'status', resp.responseCode, 'detail', NetworkService.shortText(body))
        };
      }
      return {
        responseCode: resp.responseCode,
        entities: HaEntityParser.parseMediaPlayerEntities(body),
        failureSummary: ''
      };
    } catch (err) {
      return {
        responseCode: 0,
        entities: [],
        failureSummary: NetworkService.errorText(err as Error | string | number | boolean)
      };
    }
  }

  static async setLightState(
    baseUrl: string,
    accessToken: string,
    entityId: string,
    turnOn: boolean
  ): Promise<HaLightActionResult> {
    const service = turnOn ? 'turn_on' : 'turn_off';
    try {
      const resp = await NetworkService.requestText(`${baseUrl}/api/services/light/${service}`, {
        method: NetworkHttpMethod.POST,
        header: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify({
          'entity_id': entityId
        }),
        connectTimeout: 12000,
        readTimeout: 12000
      });
      const body = resp.body;
      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        return {
          success: true,
          responseCode: resp.responseCode,
          state: turnOn ? 'on' : 'off',
          failureSummary: ''
        };
      }
      return {
        success: false,
        responseCode: resp.responseCode,
        state: '',
        failureSummary: Localization.format2('ha_error_control_light_http',
          'status', resp.responseCode, 'detail', NetworkService.shortText(body))
      };
    } catch (err) {
      return {
        success: false,
        responseCode: 0,
        state: '',
        failureSummary: NetworkService.errorText(err as Error | string | number | boolean)
      };
    }
  }

  static async fetchLightState(
    baseUrl: string,
    accessToken: string,
    entityId: string
  ): Promise<HaLightActionResult> {
    try {
      const resp = await NetworkService.requestText(`${baseUrl}/api/states/${encodeURIComponent(entityId)}`, {
        method: NetworkHttpMethod.GET,
        header: {
          'Authorization': `Bearer ${accessToken}`
        },
        connectTimeout: 5000,
        readTimeout: 5000
      });
      const body = resp.body;
      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        return {
          success: true,
          responseCode: resp.responseCode,
          state: HaEntityParser.parseLightState(body),
          failureSummary: ''
        };
      }
      return {
        success: false,
        responseCode: resp.responseCode,
        state: '',
        failureSummary: Localization.format2('ha_error_fetch_light_state_http',
          'status', resp.responseCode, 'detail', NetworkService.shortText(body))
      };
    } catch (err) {
      return {
        success: false,
        responseCode: 0,
        state: '',
        failureSummary: NetworkService.errorText(err as Error | string | number | boolean)
      };
    }
  }

  static async fetchMediaPlayerState(
    baseUrl: string,
    accessToken: string,
    entityId: string
  ): Promise<HaMediaPlayerEntity> {
    const resp = await NetworkService.requestText(`${baseUrl}/api/states/${encodeURIComponent(entityId)}`, {
      method: NetworkHttpMethod.GET,
      header: {
        'Authorization': `Bearer ${accessToken}`
      },
      connectTimeout: 5000,
      readTimeout: 5000
    });
    const body = resp.body;
    if (resp.responseCode < 200 || resp.responseCode >= 300) {
      throw new Error(Localization.format2('ha_error_fetch_media_state_http',
        'status', resp.responseCode, 'detail', NetworkService.shortText(body)));
    }
    return HaEntityParser.parseMediaPlayerState(body);
  }

  static async fetchCameraState(
    baseUrl: string,
    accessToken: string,
    entityId: string
  ): Promise<HaCameraEntity> {
    const resp = await NetworkService.requestText(`${baseUrl}/api/states/${encodeURIComponent(entityId)}`, {
      method: NetworkHttpMethod.GET,
      header: {
        'Authorization': `Bearer ${accessToken}`
      },
      connectTimeout: 5000,
      readTimeout: 5000
    });
    const body = resp.body;
    if (resp.responseCode < 200 || resp.responseCode >= 300) {
      throw new Error(Localization.format2('ha_error_fetch_media_state_http',
        'status', resp.responseCode, 'detail', NetworkService.shortText(body)));
    }
    return HaEntityParser.parseCameraState(body);
  }

  static async controlMediaPlayer(
    baseUrl: string,
    accessToken: string,
    entityId: string,
    action: string
  ): Promise<HaLightActionResult> {
    const service = HaEntityParser.mediaPlayerService(action);
    if (service.length === 0) {
      return {
        success: false,
        responseCode: 0,
        state: '',
        failureSummary: Localization.format('ha_error_unsupported_media_action', 'action', action)
      };
    }
    try {
      const resp = await NetworkService.requestText(`${baseUrl}/api/services/media_player/${service}`, {
        method: NetworkHttpMethod.POST,
        header: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify({
          'entity_id': entityId
        }),
        connectTimeout: 12000,
        readTimeout: 12000
      });
      const body = resp.body;
      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        return {
          success: true,
          responseCode: resp.responseCode,
          state: '',
          failureSummary: ''
        };
      }
      return {
        success: false,
        responseCode: resp.responseCode,
        state: '',
        failureSummary: Localization.format2('ha_error_control_media_http',
          'status', resp.responseCode, 'detail', NetworkService.shortText(body))
      };
    } catch (err) {
      return {
        success: false,
        responseCode: 0,
        state: '',
        failureSummary: NetworkService.errorText(err as Error | string | number | boolean)
      };
    }
  }

  static async activateScene(
    baseUrl: string,
    accessToken: string,
    entityId: string
  ): Promise<HaLightActionResult> {
    try {
      const resp = await NetworkService.requestText(`${baseUrl}/api/services/scene/turn_on`, {
        method: NetworkHttpMethod.POST,
        header: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify({
          'entity_id': entityId
        }),
        connectTimeout: 12000,
        readTimeout: 12000
      });
      const body = resp.body;
      if (resp.responseCode >= 200 && resp.responseCode < 300) {
        return {
          success: true,
          responseCode: resp.responseCode,
          state: 'on',
          failureSummary: ''
        };
      }
      return {
        success: false,
        responseCode: resp.responseCode,
        state: '',
        failureSummary: NetworkService.shortText(body)
      };
    } catch (err) {
      return {
        success: false,
        responseCode: 0,
        state: '',
        failureSummary: NetworkService.errorText(err as Error | string | number | boolean)
      };
    }
  }

  static async fetchConfig(baseUrl: string, accessToken: string): Promise<HaConfigFetchResult> {
    const resp = await NetworkService.requestText(`${baseUrl}/api/config`, {
      method: NetworkHttpMethod.GET,
      header: {
        'Authorization': `Bearer ${accessToken}`
      },
      connectTimeout: 10000,
      readTimeout: 10000
    });

    if (resp.responseCode >= 200 && resp.responseCode < 300) {
      const body = resp.body;
      return {
        responseCode: resp.responseCode,
        config: HaApiService.parseHaConfig(body),
        failureSummary: ''
      };
    }

    const failedBody = resp.body;
    return {
      responseCode: resp.responseCode,
      config: HaApiService.emptyConfig(),
      failureSummary: Localization.format2('ha_error_fetch_http',
        'status', resp.responseCode, 'detail', NetworkService.shortText(failedBody, 80))
    };
  }

  static async registerMobileAppDevice(
    baseUrl: string,
    accessToken: string,
    request: HaMobileAppRegistrationRequest
  ): Promise<HaMobileAppRegistrationResult> {
    const resp = await NetworkService.requestText(`${baseUrl}/api/mobile_app/registrations`, {
      method: NetworkHttpMethod.POST,
      header: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      extraData: JSON.stringify(HaApiService.buildRegistrationBody(request)),
      connectTimeout: 20000,
      readTimeout: 20000
    });

    const body = resp.body;
    if (resp.responseCode >= 200 && resp.responseCode < 300) {
      try {
        return {
          responseCode: resp.responseCode,
          registration: HaApiService.parseRegistration(body),
          failureSummary: ''
        };
      } catch (err) {
        return {
          responseCode: resp.responseCode,
          registration: HaApiService.emptyRegistration(),
          failureSummary: Localization.format2('ha_error_registration_invalid',
            'error', NetworkService.errorText(err), 'detail', NetworkService.shortText(body))
        };
      }
    }

    return {
      responseCode: resp.responseCode,
      registration: HaApiService.emptyRegistration(),
      failureSummary: Localization.format2('ha_error_registration_http',
        'status', resp.responseCode, 'detail', NetworkService.shortText(body))
    };
  }
  static async fetchConversationAgents(
    baseUrl: string,
    accessToken: string
  ): Promise<HaConversationAgentsResult> {
    return HaAssistApiService.fetchConversationAgents(baseUrl, accessToken);
  }

  static async runAssistPipelineForText(
    baseUrl: string,
    accessToken: string,
    text: string,
    pipelineId: string = '',
    conversationId: string = ''
  ): Promise<HaAssistPipelineRunResult> {
    return HaAssistApiService.runAssistPipelineForText(baseUrl, accessToken, text, pipelineId, conversationId);
  }

  private static fetchRegistryCatalog(baseUrl: string, accessToken: string): Promise<HaRegistryCatalog> {
    return HaApiService.withAuthenticatedWebSocket(baseUrl, accessToken,
      async (client, nextId): Promise<HaRegistryCatalog> => {
        const areas = await HaApiService.sendWebSocketCommand(client, nextId(), {
          'type': 'config/area_registry/list'
        });
        const devices = await HaApiService.sendWebSocketCommand(client, nextId(), {
          'type': 'config/device_registry/list'
        });
        const entities = await HaApiService.sendWebSocketCommand(client, nextId(), {
          'type': 'config/entity_registry/list'
        });
        return {
          areas: HaEntityParser.parseAreaRegistry(areas['result']),
          devices: HaEntityParser.parseDeviceRegistry(devices['result']),
          entities: HaEntityParser.parseEntityRegistry(entities['result'])
        };
      });
  }

  static parseHaConfig(body: string): HaConfigInfo {
    const parsed = JSON.parse(body) as Record<string, Object | string | number | boolean>;
    const rawLocation = parsed['location_name'];
    const rawVersion = parsed['version'];
    const rawTimezone = parsed['time_zone'];
    const rawUnitSystem = parsed['unit_system'];

    let temperatureUnit = '-';
    if (rawUnitSystem && typeof rawUnitSystem === 'object') {
      const unitObj = rawUnitSystem as Record<string, Object | string | number | boolean>;
      const rawTempUnit = unitObj['temperature'];
      if (typeof rawTempUnit === 'string' && rawTempUnit.length > 0) {
        temperatureUnit = rawTempUnit;
      }
    }

    return {
      locationName: typeof rawLocation === 'string' && rawLocation.length > 0 ? rawLocation : '-',
      version: typeof rawVersion === 'string' && rawVersion.length > 0 ? rawVersion : '-',
      timezone: typeof rawTimezone === 'string' && rawTimezone.length > 0 ? rawTimezone : '-',
      temperatureUnit
    };
  }

  static formatConfigSummary(config: HaConfigInfo): string {
    return `${config.locationName} | v${config.version} | ${config.timezone} | ${config.temperatureUnit}`;
  }

  private static emptyConfig(): HaConfigInfo {
    return {
      locationName: '-',
      version: '-',
      timezone: '-',
      temperatureUnit: '-'
    };
  }

  private static buildRegistrationBody(
    request: HaMobileAppRegistrationRequest
  ): Record<string, string | number | boolean | Record<string, string | number | boolean>> {
    return {
      'app_id': request.appId,
      'app_name': request.appName,
      'app_version': request.appVersion,
      'device_name': request.deviceName,
      'manufacturer': request.manufacturer,
      'model': request.model,
      'os_name': request.osName,
      'os_version': request.osVersion,
      'supports_encryption': request.supportsEncryption,
      'app_data': request.appData,
      'device_id': request.deviceId
    };
  }

  private static parseRegistration(body: string): HaMobileAppRegistrationInfo {
    const parsed = JSON.parse(body) as Record<string, Object | string | number | boolean | null>;
    const rawWebhookId = parsed['webhook_id'];
    if (typeof rawWebhookId !== 'string' || rawWebhookId.trim().length === 0) {
      throw new Error(Localization.t('ha_error_missing_webhook'));
    }

    const rawSecret = parsed['secret'];
    const rawCloudhookUrl = parsed['cloudhook_url'];
    const rawRemoteUiUrl = parsed['remote_ui_url'];
    return {
      webhookId: rawWebhookId,
      webhookSecret: typeof rawSecret === 'string' ? rawSecret : '',
      cloudhookUrl: '',
      remoteUiUrl: typeof rawRemoteUiUrl === 'string' ? rawRemoteUiUrl : ''
    };
  }

  private static emptyRegistration(): HaMobileAppRegistrationInfo {
    return {
      webhookId: '',
      webhookSecret: '',
      cloudhookUrl: '',
      remoteUiUrl: ''
    };
  }

  private static withAuthenticatedWebSocket<T>(
    baseUrl: string,
    accessToken: string,
    action: (client: NetworkWebSocket, nextId: () => number) => Promise<T>
  ): Promise<T> {
    return new Promise<T>((resolve, reject): void => {
      const client = NetworkService.createWebSocket();
      const url = HaApiService.webSocketUrl(baseUrl);
      let messageId = 1;
      let finished = false;
      const timeoutId = setTimeout((): void => {
        if (!finished) {
          finished = true;
          cleanup();
          reject(new Error(Localization.t('ha_error_ws_connect_timeout')));
        }
      }, 15000);

      const nextId = (): number => {
        const value = messageId;
        messageId += 1;
        return value;
      };
      const cleanup = (): void => {
        clearTimeout(timeoutId);
        client.off('message', onMessage);
        client.off('error', onError);
        client.off('close', onClose);
        client.close().catch((): void => {});
      };
      const complete = (value: T): void => {
        if (finished) {
          return;
        }
        finished = true;
        cleanup();
        resolve(value);
      };
      const fail = (err: Error): void => {
        if (finished) {
          return;
        }
        finished = true;
        cleanup();
        reject(err);
      };
      const onError = (err: Error): void => {
        fail(err);
      };
      const onClose = (): void => {
        if (!finished) {
          fail(new Error(Localization.t('ha_error_ws_closed')));
        }
      };
      const onMessage = (err: Error, data: string | ArrayBuffer): void => {
        if (err) {
          fail(err);
          return;
        }
        const messageText = HaApiService.webSocketMessageText(data);
        if (messageText.length === 0) {
          return;
        }
        try {
          const message = JSON.parse(messageText) as Record<string, Object | string | number | boolean | null>;
          const type = message['type'];
          if (type === 'auth_required') {
            client.send(JSON.stringify({
              'type': 'auth',
              'access_token': accessToken
            })).catch((sendErr: Error): void => {
              fail(sendErr);
            });
            return;
          }
          if (type === 'auth_invalid') {
            fail(new Error(HaApiService.parseWebSocketError(message)));
            return;
          }
          if (type === 'auth_ok') {
            action(client, nextId).then((value: T): void => {
              complete(value);
            }).catch((actionErr: Error): void => {
              fail(actionErr);
            });
          }
        } catch (parseErr) {
          fail(new Error(Localization.format('ha_error_ws_handshake_parse', 'error',
            NetworkService.errorText(parseErr as Error | string | number | boolean))));
        }
      };

      client.on('message', onMessage);
      client.on('error', onError);
      client.on('close', onClose);
      client.connect(url, {
        pingInterval: 30,
        pongTimeout: 10
      }).catch((connectErr: Error): void => {
        fail(connectErr);
      });
    });
  }

  private static sendWebSocketCommand(
    client: NetworkWebSocket,
    id: number,
    command: Record<string, Object | string | number | boolean | null>
  ): Promise<Record<string, Object | string | number | boolean | null>> {
    return new Promise<Record<string, Object | string | number | boolean | null>>((resolve, reject): void => {
      let finished = false;
      const timeoutId = setTimeout((): void => {
        if (!finished) {
          finished = true;
          cleanup();
          reject(new Error(Localization.format('ha_error_ws_command_timeout', 'type', `${command['type']}`)));
        }
      }, 15000);
      const cleanup = (): void => {
        clearTimeout(timeoutId);
        client.off('message', onMessage);
        client.off('error', onError);
      };
      const fail = (err: Error): void => {
        if (finished) {
          return;
        }
        finished = true;
        cleanup();
        reject(err);
      };
      const onError = (err: Error): void => {
        fail(err);
      };
      const onMessage = (err: Error, data: string | ArrayBuffer): void => {
        if (err) {
          fail(err);
          return;
        }
        const messageText = HaApiService.webSocketMessageText(data);
        if (messageText.length === 0) {
          return;
        }
        try {
          const message = JSON.parse(messageText) as Record<string, Object | string | number | boolean | null>;
          if (message['type'] !== 'result' || message['id'] !== id) {
            return;
          }
          if (message['success'] === false) {
            fail(new Error(HaApiService.parseWebSocketError(message)));
            return;
          }
          finished = true;
          cleanup();
          resolve(message);
        } catch (parseErr) {
          fail(new Error(Localization.format('ha_error_ws_command_parse', 'error',
            NetworkService.errorText(parseErr as Error | string | number | boolean))));
        }
      };
      client.on('message', onMessage);
      client.on('error', onError);
      client.send(JSON.stringify(HaApiService.commandWithId(id, command))).catch((sendErr: Error): void => {
        fail(sendErr);
      });
    });
  }

  private static commandWithId(
    id: number,
    command: Record<string, Object | string | number | boolean | null>
  ): Record<string, Object | string | number | boolean | null> {
    const payload: Record<string, Object | string | number | boolean | null> = {
      'id': id
    };
    const keys = Object.keys(command);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      payload[key] = command[key];
    }
    return payload;
  }

  private static webSocketUrl(baseUrl: string): string {
    const normalized = baseUrl.replace(/\/+$/, '');
    if (normalized.startsWith('https://')) {
      return `wss://${normalized.slice('https://'.length)}/api/websocket`;
    }
    if (normalized.startsWith('http://')) {
      return `ws://${normalized.slice('http://'.length)}/api/websocket`;
    }
    return `${normalized}/api/websocket`;
  }

  private static webSocketMessageText(data: string | ArrayBuffer): string {
    if (typeof data === 'string') {
      return data;
    }
    return '';
  }

  private static objectField(
    source: Record<string, Object | string | number | boolean | null>,
    key: string
  ): Record<string, Object | string | number | boolean | null> | null {
    const value = source[key];
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      return value as Record<string, Object | string | number | boolean | null>;
    }
    return null;
  }

  private static parseWebSocketError(message: Record<string, Object | string | number | boolean | null>): string {
    const rawMessage = message['message'];
    if (typeof rawMessage === 'string' && rawMessage.trim().length > 0) {
      return rawMessage.trim();
    }
    const error = HaApiService.objectField(message, 'error');
    if (error) {
      const errorMessage = error['message'];
      if (typeof errorMessage === 'string' && errorMessage.trim().length > 0) {
        return errorMessage.trim();
      }
      const code = error['code'];
      if (typeof code === 'string' && code.trim().length > 0) {
        return code.trim();
      }
    }
    return Localization.t('ha_error_ws_request');
  }

}
