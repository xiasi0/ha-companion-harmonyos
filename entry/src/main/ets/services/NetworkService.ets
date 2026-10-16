// Shared HTTP and WebSocket wrapper for platform networking.
// Business services use this layer to keep timeout, body parsing, and error text behavior consistent.
import common from '@ohos.app.ability.common';
import { connection, http, mdns, webSocket } from '@kit.NetworkKit';
import { Localization } from '../shared/i18n/Localization';
import {
  HomeNetworkEvaluation,
  HomeNetworkService,
  HomeNetworkSettings,
  WirelessSnapshot
} from './HomeNetworkService';
import { NativeWirelessProvider } from './NativeWirelessProvider';

export type NetworkWebSocket = webSocket.WebSocket;
export type NetworkMdnsDiscoveryService = mdns.DiscoveryService;
export type NetworkMdnsLocalServiceInfo = mdns.LocalServiceInfo;
export type NetworkNetCap = connection.NetCap;
export type NetworkNetBearType = connection.NetBearType;
export type NetworkNetConnection = connection.NetConnection;

export enum NetworkHttpMethod {
  GET = 'GET',
  POST = 'POST'
}

export interface NetworkRequestOptions {
  method: NetworkHttpMethod;
  header?: Record<string, string>;
  extraData?: string | Object | ArrayBuffer;
  connectTimeout?: number;
  readTimeout?: number;
}

export interface NetworkTextResponse {
  responseCode: number;
  body: string;
}

export interface NetworkBufferResponse {
  responseCode: number;
  body: ArrayBuffer;
}

export enum NetworkCapabilityStatus {
  AVAILABLE,
  PLACEHOLDER,
  UNSUPPORTED
}

export interface NetworkCapabilityInfo {
  title: string;
  summary: string;
  status: NetworkCapabilityStatus;
}

export class NetworkService {
  static readonly ANDROID_CLIENT_ID: string = 'https://home-assistant.io/android';
  static readonly ANDROID_COMPATIBLE_USER_AGENT: string =
    'Mozilla/5.0 (Linux; Android 13; HarmonyOS) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36 Home Assistant';

  static async requestText(url: string, options: NetworkRequestOptions): Promise<NetworkTextResponse> {
    const response = await NetworkService.request(url, options, false);
    return {
      responseCode: response.responseCode,
      body: NetworkService.safeBodyText(response.result)
    };
  }

  static async requestBuffer(url: string, options: NetworkRequestOptions): Promise<NetworkBufferResponse> {
    const response = await NetworkService.request(url, options, true);
    return {
      responseCode: response.responseCode,
      body: response.result instanceof ArrayBuffer ? response.result : new ArrayBuffer(0)
    };
  }

  static createWebSocket(): NetworkWebSocket {
    return webSocket.createWebSocket();
  }

  static createMdnsDiscoveryService(context: common.Context, serviceType: string): NetworkMdnsDiscoveryService {
    try {
      return mdns.createDiscoveryService(context, serviceType);
    } catch (error) {
      throw NetworkService.errorFrom(error);
    }
  }

  static resolveMdnsLocalService(
    context: common.Context,
    serviceInfo: NetworkMdnsLocalServiceInfo
  ): Promise<NetworkMdnsLocalServiceInfo> {
    try {
      return mdns.resolveLocalService(context, serviceInfo);
    } catch (error) {
      throw NetworkService.errorFrom(error);
    }
  }

  static createNetConnection(): NetworkNetConnection {
    try {
      return connection.createNetConnection();
    } catch (error) {
      throw NetworkService.errorFrom(error);
    }
  }

  static async wirelessSnapshot(): Promise<WirelessSnapshot> {
    return NativeWirelessProvider.currentSnapshot();
  }

  static async homeNetworkState(settings: HomeNetworkSettings): Promise<HomeNetworkEvaluation> {
    return HomeNetworkService.evaluate(await NetworkService.wirelessSnapshot(), settings);
  }

  static normalizeWifiSsids(ssids: string[]): string[] {
    return HomeNetworkService.normalizeSsidList(ssids);
  }

  static subscribeWirelessEvents(callback: () => void): void {
    NativeWirelessProvider.subscribe(callback);
  }

  static unsubscribeWirelessEvents(callback: () => void): void {
    NativeWirelessProvider.unsubscribe(callback);
  }

  static defaultNetCapabilities(): connection.NetCapabilities {
    try {
      const defaultNet = connection.getDefaultNetSync();
      return connection.getNetCapabilitiesSync(defaultNet);
    } catch (error) {
      throw NetworkService.errorFrom(error);
    }
  }

  static isNotMeteredCap(target: NetworkNetCap): boolean {
    return target === connection.NetCap.NET_CAPABILITY_NOT_METERED;
  }

  static isCellularBearer(target: NetworkNetBearType): boolean {
    return target === connection.NetBearType.BEARER_CELLULAR;
  }

  static isEthernetBearer(target: NetworkNetBearType): boolean {
    return target === connection.NetBearType.BEARER_ETHERNET;
  }

  static isVpnBearer(target: NetworkNetBearType): boolean {
    return target === connection.NetBearType.BEARER_VPN;
  }

  static isWifiBearer(target: NetworkNetBearType): boolean {
    return target === connection.NetBearType.BEARER_WIFI;
  }

  static isSuccessStatus(responseCode: number): boolean {
    return responseCode >= 200 && responseCode < 300;
  }

  static safeBodyText(result: Object | string | number | ArrayBuffer): string {
    try {
      if (typeof result === 'string') {
        return result;
      }
      if (typeof result === 'number') {
        return String(result);
      }
      if (result instanceof ArrayBuffer) {
        return `[ArrayBuffer ${result.byteLength} bytes]`;
      }
      return JSON.stringify(result);
    } catch (_) {
      return '[unreadable body]';
    }
  }

  static shortText(input: string, maxLen: number = 120): string {
    const normalized = input.replace(/\s+/g, ' ').trim();
    if (normalized.length <= maxLen) {
      return normalized;
    }
    return `${normalized.slice(0, maxLen)}...`;
  }

  static errorText(err: Error | string | number | boolean | Object | ArrayBuffer, fallback: string = ''): string {
    if (err instanceof Error && err.message) {
      return err.message;
    }
    if (typeof err === 'string') {
      return err;
    }
    if (typeof err === 'number' || typeof err === 'boolean') {
      return `${err}`;
    }
    if (err instanceof ArrayBuffer) {
      return `[ArrayBuffer ${err.byteLength} bytes]`;
    }
    try {
      return JSON.stringify(err);
    } catch (_) {
      return fallback.length > 0 ? fallback : `${err}`;
    }
  }

  static homeNetworkEntries(): NetworkCapabilityInfo[] {
    return [
      {
        title: Localization.t('network_status_title'),
        summary: Localization.t('network_status_summary'),
        status: NetworkCapabilityStatus.PLACEHOLDER
      },
      {
        title: Localization.t('network_home_title'),
        summary: Localization.t('network_home_summary'),
        status: NetworkCapabilityStatus.PLACEHOLDER
      }
    ];
  }

  static statusLabel(status: NetworkCapabilityStatus): string {
    if (status === NetworkCapabilityStatus.AVAILABLE) {
      return Localization.t('common_available');
    }
    if (status === NetworkCapabilityStatus.UNSUPPORTED) {
      return Localization.t('state_unsupported');
    }
    return Localization.t('settings_switch_pending');
  }

  private static async request(
    url: string,
    options: NetworkRequestOptions,
    expectBuffer: boolean
  ): Promise<http.HttpResponse> {
    const client = NetworkService.createHttpClient();
    try {
      return await NetworkService.executeRequest(client, url, options, expectBuffer);
    } finally {
      NetworkService.destroyHttpClient(client);
    }
  }

  private static async executeRequest(
    client: http.HttpRequest,
    url: string,
    options: NetworkRequestOptions,
    expectBuffer: boolean
  ): Promise<http.HttpResponse> {
    try {
      return await client.request(url, NetworkService.toHttpOptions(options, expectBuffer));
    } catch (error) {
      throw NetworkService.errorFrom(error);
    }
  }

  private static createHttpClient(): http.HttpRequest {
    try {
      return http.createHttp();
    } catch (error) {
      throw NetworkService.errorFrom(error);
    }
  }

  private static destroyHttpClient(client: http.HttpRequest): void {
    try {
      client.destroy();
    } catch (_) {
    }
  }

  private static toHttpOptions(options: NetworkRequestOptions, expectBuffer: boolean): http.HttpRequestOptions {
    const httpOptions: http.HttpRequestOptions = {
      method: NetworkService.toHttpMethod(options.method),
      header: NetworkService.mergeHeaders(options.header)
    };
    if (options.extraData !== undefined) {
      httpOptions.extraData = options.extraData;
    }
    if (options.connectTimeout !== undefined) {
      httpOptions.connectTimeout = options.connectTimeout;
    }
    if (options.readTimeout !== undefined) {
      httpOptions.readTimeout = options.readTimeout;
    }
    if (expectBuffer) {
      httpOptions.expectDataType = http.HttpDataType.ARRAY_BUFFER;
    }
    return httpOptions;
  }

  private static toHttpMethod(method: NetworkHttpMethod): http.RequestMethod {
    if (method === NetworkHttpMethod.POST) {
      return http.RequestMethod.POST;
    }
    return http.RequestMethod.GET;
  }

  private static mergeHeaders(source: Record<string, string> | undefined): Record<string, string> {
    const headers: Record<string, string> = {
      'User-Agent': NetworkService.ANDROID_COMPATIBLE_USER_AGENT,
      'X-HomeAssistant-Client': 'Android'
    };
    if (!source) {
      return headers;
    }
    const keys = Object.keys(source);
    for (let i = 0; i < keys.length; i++) {
      headers[keys[i]] = source[keys[i]];
    }
    return headers;
  }

  private static errorFrom(error: Error): Error {
    return error;
  }
}
