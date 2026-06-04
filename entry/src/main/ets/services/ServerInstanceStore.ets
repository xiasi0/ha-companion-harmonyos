// Durable multi-server store backed by HarmonyOS app account and asset APIs.
// The runtime order and active server pointer are kept in preferences for fast startup.
import appAccount from '@ohos.account.appAccount';
import common from '@ohos.app.ability.common';
import preferences from '@ohos.data.preferences';
import { StoredServerInfo, StorageService } from './StorageService';
import { SystemAssetStore } from './SystemAssetStore';

export interface ServerInstanceRecord {
  id: string;
  name: string;
  info: StoredServerInfo;
  createdAt: number;
  updatedAt: number;
}

export interface ServerRuntimeState {
  activeServerId: string;
  serverOrder: string[];
}

interface AppAccountListRecord {
  name: string;
}

class ServerInstancePayload implements ServerInstanceRecord {
  id: string = '';
  name: string = '';
  info: StoredServerInfo = StorageService.emptyServerInfo();
  createdAt: number = 0;
  updatedAt: number = 0;
}

class ServerRuntimePayload implements ServerRuntimeState {
  activeServerId: string = '';
  serverOrder: string[] = [];
}

export class ServerInstanceStore {
  static readonly ACCOUNT_PREFIX: string = 'ha_server_';
  private static readonly RUNTIME_PREFERENCES_NAME: string = 'ha_server_runtime';
  private static readonly ACTIVE_SERVER_ID: string = 'active_server_id';
  private static readonly SERVER_ORDER: string = 'server_order';
  private static readonly ACCESS_TOKEN: string = 'access_token';
  private static readonly REFRESH_TOKEN: string = 'refresh_token';
  private static readonly WEBHOOK_SECRET: string = 'webhook_secret';

  static async list(context: common.Context): Promise<ServerInstanceRecord[]> {
    const accounts = await ServerInstanceStore.getAllAccounts();
    const records: ServerInstanceRecord[] = [];
    for (let i = 0; i < accounts.length; i++) {
      const id = ServerInstanceStore.idFromAccountName(accounts[i].name);
      if (id.length === 0) {
        continue;
      }
      const record = await ServerInstanceStore.load(context, id);
      if (record && StorageService.hasCredentials(record.info)) {
        records.push(record);
      }
    }
    return ServerInstanceStore.applyOrder(records, await ServerInstanceStore.loadRuntime(context));
  }

  static async load(_context: common.Context, id: string): Promise<ServerInstanceRecord | undefined> {
    const normalized = ServerInstanceStore.normalizeId(id);
    if (normalized.length === 0) {
      return undefined;
    }
    return ServerInstanceStore.loadSyncById(normalized);
  }

  static loadSync(_context: common.Context, id: string): ServerInstanceRecord | undefined {
    return ServerInstanceStore.loadSyncById(ServerInstanceStore.normalizeId(id));
  }

  static async save(context: common.Context, existingId: string, name: string, info: StoredServerInfo): Promise<ServerInstanceRecord> {
    const normalizedInfo = ServerInstanceStore.normalizeInfo(info);
    const now = Date.now();
    let id = ServerInstanceStore.normalizeId(existingId);
    if (id.length === 0) {
      id = ServerInstanceStore.newId(now);
    }
    const current = ServerInstanceStore.loadSync(context, id);
    const createdAt = current ? current.createdAt : now;
    await ServerInstanceStore.ensureAccount(id);
    await ServerInstanceStore.setCustomData(id, 'baseUrl', normalizedInfo.baseUrl);
    await ServerInstanceStore.setCustomData(id, 'displayName', name.trim());
    await ServerInstanceStore.setCustomData(id, 'deviceName', normalizedInfo.deviceName);
    await ServerInstanceStore.setCustomData(id, 'mobileAppDeviceId', normalizedInfo.mobileAppDeviceId);
    await ServerInstanceStore.setCustomData(id, 'webhookId', normalizedInfo.webhookId);
    await ServerInstanceStore.setCustomData(id, 'cloudhookUrl', normalizedInfo.cloudhookUrl);
    await ServerInstanceStore.setCustomData(id, 'remoteUiUrl', normalizedInfo.remoteUiUrl);
    await ServerInstanceStore.setCustomData(id, 'accessTokenExpiresAt', `${normalizedInfo.accessTokenExpiresAt}`);
    await ServerInstanceStore.setCustomData(id, 'createdAt', `${createdAt}`);
    await ServerInstanceStore.setCustomData(id, 'updatedAt', `${now}`);
    await SystemAssetStore.saveString(ServerInstanceStore.assetAlias(id, ServerInstanceStore.ACCESS_TOKEN), normalizedInfo.accessToken);
    await SystemAssetStore.saveString(ServerInstanceStore.assetAlias(id, ServerInstanceStore.REFRESH_TOKEN), normalizedInfo.refreshToken);
    await SystemAssetStore.saveString(ServerInstanceStore.assetAlias(id, ServerInstanceStore.WEBHOOK_SECRET), normalizedInfo.webhookSecret);
    const runtime = await ServerInstanceStore.loadRuntime(context);
    if (!runtime.serverOrder.includes(id)) {
      runtime.serverOrder.push(id);
    }
    await ServerInstanceStore.saveRuntime(context, runtime);
    return ServerInstanceStore.loadSync(context, id) ?? ServerInstanceStore.payload(id, name, normalizedInfo, createdAt, now);
  }

  static async remove(context: common.Context, id: string): Promise<void> {
    const normalized = ServerInstanceStore.normalizeId(id);
    if (normalized.length === 0) {
      return;
    }
    const manager = appAccount.createAppAccountManager();
    try {
      await manager.removeAccount(ServerInstanceStore.accountName(normalized));
    } catch (_) {
    }
    await SystemAssetStore.remove(ServerInstanceStore.assetAlias(normalized, ServerInstanceStore.ACCESS_TOKEN));
    await SystemAssetStore.remove(ServerInstanceStore.assetAlias(normalized, ServerInstanceStore.REFRESH_TOKEN));
    await SystemAssetStore.remove(ServerInstanceStore.assetAlias(normalized, ServerInstanceStore.WEBHOOK_SECRET));
    const runtime = await ServerInstanceStore.loadRuntime(context);
    runtime.serverOrder = runtime.serverOrder.filter((item: string): boolean => item !== normalized);
    if (runtime.activeServerId === normalized) {
      runtime.activeServerId = runtime.serverOrder.length > 0 ? runtime.serverOrder[runtime.serverOrder.length - 1] : '';
    }
    await ServerInstanceStore.saveRuntime(context, runtime);
  }

  static async clearAll(context: common.Context): Promise<void> {
    const records = await ServerInstanceStore.list(context);
    for (let i = 0; i < records.length; i++) {
      await ServerInstanceStore.remove(context, records[i].id);
    }
    await ServerInstanceStore.saveRuntime(context, new ServerRuntimePayload());
  }

  static async loadRuntime(context: common.Context): Promise<ServerRuntimeState> {
    const state = new ServerRuntimePayload();
    try {
      const pref = await ServerInstanceStore.getPreferences(context);
      state.activeServerId = ServerInstanceStore.stringValue(await ServerInstanceStore.getValue(pref, ServerInstanceStore.ACTIVE_SERVER_ID, ''));
      state.serverOrder = ServerInstanceStore.parseStringArray(await ServerInstanceStore.getValue(pref, ServerInstanceStore.SERVER_ORDER, '[]'));
    } catch (_) {
      return state;
    }
    return state;
  }

  static loadRuntimeSync(context: common.Context): ServerRuntimeState {
    const state = new ServerRuntimePayload();
    try {
      const pref = preferences.getPreferencesSync(context, { name: ServerInstanceStore.RUNTIME_PREFERENCES_NAME });
      state.activeServerId = ServerInstanceStore.stringValue(pref.getSync(ServerInstanceStore.ACTIVE_SERVER_ID, ''));
      state.serverOrder = ServerInstanceStore.parseStringArray(pref.getSync(ServerInstanceStore.SERVER_ORDER, '[]'));
    } catch (_) {
      return state;
    }
    return state;
  }

  static async saveRuntime(context: common.Context, state: ServerRuntimeState): Promise<void> {
    try {
      const pref = await ServerInstanceStore.getPreferences(context);
      await ServerInstanceStore.putValue(pref, ServerInstanceStore.ACTIVE_SERVER_ID, state.activeServerId);
      await ServerInstanceStore.putValue(pref, ServerInstanceStore.SERVER_ORDER, JSON.stringify(state.serverOrder));
      await ServerInstanceStore.flush(pref);
    } catch (error) {
      throw ServerInstanceStore.errorFrom(error);
    }
  }

  private static async ensureAccount(id: string): Promise<void> {
    const manager = appAccount.createAppAccountManager();
    try {
      await manager.createAccount(ServerInstanceStore.accountName(id));
    } catch (_) {
    }
  }

  private static async setCustomData(id: string, key: string, value: string): Promise<void> {
    const manager = appAccount.createAppAccountManager();
    try {
      await manager.setCustomData(ServerInstanceStore.accountName(id), key, value);
    } catch (error) {
      throw ServerInstanceStore.errorFrom(error);
    }
  }

  private static async getAllAccounts(): Promise<AppAccountListRecord[]> {
    const manager = appAccount.createAppAccountManager();
    try {
      return await manager.getAllAccounts() as AppAccountListRecord[];
    } catch (_) {
      return [];
    }
  }

  private static async getPreferences(context: common.Context): Promise<preferences.Preferences> {
    try {
      return await preferences.getPreferences(context, ServerInstanceStore.RUNTIME_PREFERENCES_NAME);
    } catch (error) {
      throw ServerInstanceStore.errorFrom(error);
    }
  }

  private static async getValue(
    pref: preferences.Preferences,
    key: string,
    defaultValue: preferences.ValueType
  ): Promise<preferences.ValueType> {
    try {
      return await pref.get(key, defaultValue);
    } catch (error) {
      throw ServerInstanceStore.errorFrom(error);
    }
  }

  private static async putValue(
    pref: preferences.Preferences,
    key: string,
    value: preferences.ValueType
  ): Promise<void> {
    try {
      await pref.put(key, value);
    } catch (error) {
      throw ServerInstanceStore.errorFrom(error);
    }
  }

  private static async flush(pref: preferences.Preferences): Promise<void> {
    try {
      await pref.flush();
    } catch (error) {
      throw ServerInstanceStore.errorFrom(error);
    }
  }

  private static loadSyncById(id: string): ServerInstanceRecord | undefined {
    if (id.length === 0) {
      return undefined;
    }
    const manager = appAccount.createAppAccountManager();
    const accountName = ServerInstanceStore.accountName(id);
    try {
      const info = StorageService.serverInfo(
        ServerInstanceStore.customData(manager, accountName, 'baseUrl'),
        SystemAssetStore.loadStringSync(ServerInstanceStore.assetAlias(id, ServerInstanceStore.ACCESS_TOKEN)),
        SystemAssetStore.loadStringSync(ServerInstanceStore.assetAlias(id, ServerInstanceStore.REFRESH_TOKEN)),
        ServerInstanceStore.numberText(ServerInstanceStore.customData(manager, accountName, 'accessTokenExpiresAt')),
        ServerInstanceStore.customData(manager, accountName, 'deviceName'),
        ServerInstanceStore.customData(manager, accountName, 'mobileAppDeviceId'),
        ServerInstanceStore.customData(manager, accountName, 'webhookId'),
        SystemAssetStore.loadStringSync(ServerInstanceStore.assetAlias(id, ServerInstanceStore.WEBHOOK_SECRET)),
        ServerInstanceStore.customData(manager, accountName, 'cloudhookUrl'),
        ServerInstanceStore.customData(manager, accountName, 'remoteUiUrl')
      );
      if (!StorageService.hasCredentials(info)) {
        return undefined;
      }
      return ServerInstanceStore.payload(
        id,
        ServerInstanceStore.customData(manager, accountName, 'displayName'),
        ServerInstanceStore.normalizeInfo(info),
        ServerInstanceStore.numberText(ServerInstanceStore.customData(manager, accountName, 'createdAt')),
        ServerInstanceStore.numberText(ServerInstanceStore.customData(manager, accountName, 'updatedAt'))
      );
    } catch (_) {
      return undefined;
    }
  }

  private static customData(manager: appAccount.AppAccountManager, accountName: string, key: string): string {
    try {
      return manager.getCustomDataSync(accountName, key) ?? '';
    } catch (_) {
      return '';
    }
  }

  private static payload(
    id: string,
    name: string,
    info: StoredServerInfo,
    createdAt: number,
    updatedAt: number
  ): ServerInstanceRecord {
    const record = new ServerInstancePayload();
    record.id = id;
    record.name = name.trim();
    record.info = info;
    record.createdAt = createdAt > 0 ? createdAt : Date.now();
    record.updatedAt = updatedAt > 0 ? updatedAt : record.createdAt;
    return record;
  }

  private static applyOrder(records: ServerInstanceRecord[], runtime: ServerRuntimeState): ServerInstanceRecord[] {
    const ordered: ServerInstanceRecord[] = [];
    for (let i = 0; i < runtime.serverOrder.length; i++) {
      const id = runtime.serverOrder[i];
      const record = records.find((item: ServerInstanceRecord): boolean => item.id === id);
      if (record) {
        ordered.push(record);
      }
    }
    for (let i = 0; i < records.length; i++) {
      if (!ordered.some((item: ServerInstanceRecord): boolean => item.id === records[i].id)) {
        ordered.push(records[i]);
      }
    }
    return ordered;
  }

  private static accountName(id: string): string {
    return `${ServerInstanceStore.ACCOUNT_PREFIX}${ServerInstanceStore.normalizeId(id)}`;
  }

  private static idFromAccountName(name: string): string {
    const value = name.trim();
    if (!value.startsWith(ServerInstanceStore.ACCOUNT_PREFIX)) {
      return '';
    }
    return ServerInstanceStore.normalizeId(value.substring(ServerInstanceStore.ACCOUNT_PREFIX.length));
  }

  private static assetAlias(id: string, kind: string): string {
    return `${ServerInstanceStore.ACCOUNT_PREFIX}${ServerInstanceStore.normalizeId(id)}_${kind}`;
  }

  private static newId(now: number): string {
    return `${now.toString(36)}_${Math.floor(Math.random() * 2147483647).toString(36)}`;
  }

  private static normalizeId(value: string): string {
    return value.trim().replace(/[^A-Za-z0-9_-]/g, '_');
  }

  private static normalizeInfo(info: StoredServerInfo): StoredServerInfo {
    return StorageService.serverInfo(
      info.baseUrl.trim().replace(/\/+$/, ''),
      info.accessToken.trim(),
      info.refreshToken.trim(),
      info.accessTokenExpiresAt,
      info.deviceName.trim(),
      info.mobileAppDeviceId.trim(),
      info.webhookId.trim(),
      info.webhookSecret.trim(),
      info.cloudhookUrl.trim(),
      info.remoteUiUrl.trim()
    );
  }

  private static stringValue(value: preferences.ValueType): string {
    return typeof value === 'string' ? value : '';
  }

  private static numberValue(value: preferences.ValueType): number {
    return typeof value === 'number' ? value : 0;
  }

  private static numberText(value: string): number {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  private static parseStringArray(value: preferences.ValueType): string[] {
    if (typeof value !== 'string' || value.trim().length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(value) as string[];
      return Array.isArray(parsed)
        ? parsed.filter((item: string): boolean => typeof item === 'string' && item.trim().length > 0)
        : [];
    } catch (_) {
      return [];
    }
  }

  private static errorFrom(error: Error): Error {
    return error;
  }
}
