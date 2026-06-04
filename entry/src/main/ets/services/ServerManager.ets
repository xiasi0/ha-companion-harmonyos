// High-level server account coordinator.
// It applies runtime state changes while delegating durable account storage to ServerInstanceStore.
import common from '@ohos.app.ability.common';
import { AppSettingsStore } from './AppSettingsStore';
import { ServerInstanceRecord, ServerInstanceStore, ServerRuntimeState } from './ServerInstanceStore';
import { StoredServerInfo, StorageService } from './StorageService';

export interface ManagedServer {
  id: string;
  name: string;
  info: StoredServerInfo;
  createdAt: number;
  updatedAt: number;
}

class ManagedServerPayload implements ManagedServer {
  id: string = '';
  name: string = '';
  info: StoredServerInfo = StorageService.emptyServerInfo();
  createdAt: number = 0;
  updatedAt: number = 0;
}

export class ServerManager {
  static async restoreActiveToAppStorage(context: common.Context): Promise<StoredServerInfo> {
    const info = await ServerManager.getActiveServerInfo(context);
    ServerManager.applyActiveToAppStorage(info);
    return info;
  }

  static async listServers(context: common.Context): Promise<ManagedServer[]> {
    const runtime = await ServerInstanceStore.loadRuntime(context);
    const records = await ServerManager.deduplicateServersByBaseUrl(context, await ServerInstanceStore.list(context), runtime);
    return records.map((record: ServerInstanceRecord): ManagedServer => {
      return ServerManager.managedServer(record);
    });
  }

  static async getActiveServer(context: common.Context): Promise<ManagedServer | undefined> {
    const runtime = await ServerInstanceStore.loadRuntime(context);
    const active = await ServerManager.findActiveServer(context, runtime);
    return active ? ServerManager.managedServer(active) : undefined;
  }

  static async getActiveServerInfo(context: common.Context): Promise<StoredServerInfo> {
    const active = await ServerManager.getActiveServer(context);
    return active ? active.info : StorageService.emptyServerInfo();
  }

  static getActiveServerInfoSync(context: common.Context): StoredServerInfo {
    const active = ServerManager.getActiveServerSync(context);
    return active ? active.info : StorageService.emptyServerInfo();
  }

  static getActiveServerIdSync(context: common.Context): string {
    const active = ServerManager.getActiveServerSync(context);
    return active ? active.id : '';
  }

  static getServerInfoSync(context: common.Context, id: string): StoredServerInfo {
    const record = ServerInstanceStore.loadSync(context, id);
    return record ? record.info : StorageService.emptyServerInfo();
  }

  static findServerIdByBaseUrlSync(context: common.Context, baseUrl: string): string {
    const target = ServerManager.normalizeBaseUrl(baseUrl);
    if (target.length === 0) {
      return '';
    }
    const runtime = ServerInstanceStore.loadRuntimeSync(context);
    for (let i = 0; i < runtime.serverOrder.length; i++) {
      const record = ServerInstanceStore.loadSync(context, runtime.serverOrder[i]);
      if (record && ServerManager.normalizeBaseUrl(record.info.baseUrl) === target) {
        return record.id;
      }
    }
    return '';
  }

  static async getServerInfo(context: common.Context, id: string): Promise<StoredServerInfo> {
    const record = await ServerInstanceStore.load(context, id);
    return record ? record.info : StorageService.emptyServerInfo();
  }

  static async saveActiveServerInfo(context: common.Context, info: StoredServerInfo): Promise<ManagedServer> {
    const normalized = ServerManager.normalizeInfo(info);
    if (!StorageService.hasLogin(normalized)) {
      const active = ServerManager.getActiveServerSync(context);
      if (active &&
        ServerManager.normalizeBaseUrl(active.info.baseUrl) === ServerManager.normalizeBaseUrl(normalized.baseUrl)) {
        const next = await ServerManager.removeActiveServer(context);
        ServerManager.applyActiveToAppStorage(next);
      } else {
        ServerManager.applyActiveToAppStorage(normalized);
      }
      return new ManagedServerPayload();
    }
    const runtime = await ServerInstanceStore.loadRuntime(context);
    const activeId = runtime.activeServerId;
    const active = activeId.length > 0 ? ServerInstanceStore.loadSync(context, activeId) : undefined;
    const existing = await ServerManager.findExistingServerByBaseUrl(context, normalized.baseUrl);
    const activeMatches = active &&
      ServerManager.normalizeBaseUrl(active.info.baseUrl) === ServerManager.normalizeBaseUrl(normalized.baseUrl);
    const target = activeMatches ? active : existing;
    const saved = await ServerInstanceStore.save(context, target ? target.id : '', target ? target.name : '', normalized);
    runtime.activeServerId = saved.id;
    if (!runtime.serverOrder.includes(saved.id)) {
      runtime.serverOrder.push(saved.id);
    }
    await ServerInstanceStore.saveRuntime(context, runtime);
    ServerManager.applyActiveToAppStorage(saved.info);
    return ServerManager.managedServer(saved);
  }

  static async addServerAndActivate(context: common.Context, info: StoredServerInfo): Promise<ManagedServer> {
    const normalized = ServerManager.normalizeInfo(info);
    if (!StorageService.hasLogin(normalized)) {
      ServerManager.applyActiveToAppStorage(normalized);
      return new ManagedServerPayload();
    }
    const records = await ServerInstanceStore.list(context);
    const existing = records.find((server: ServerInstanceRecord): boolean => {
      return ServerManager.normalizeBaseUrl(server.info.baseUrl) === ServerManager.normalizeBaseUrl(normalized.baseUrl);
    });
    const saved = await ServerInstanceStore.save(context, existing ? existing.id : '', existing ? existing.name : '', normalized);
    const runtime = await ServerInstanceStore.loadRuntime(context);
    runtime.activeServerId = saved.id;
    if (!runtime.serverOrder.includes(saved.id)) {
      runtime.serverOrder.push(saved.id);
    }
    await ServerInstanceStore.saveRuntime(context, runtime);
    ServerManager.applyActiveToAppStorage(saved.info);
    return ServerManager.managedServer(saved);
  }

  static async activateServer(context: common.Context, id: string): Promise<StoredServerInfo> {
    const record = await ServerInstanceStore.load(context, id);
    if (!record) {
      return StorageService.emptyServerInfo();
    }
    const runtime = await ServerInstanceStore.loadRuntime(context);
    runtime.activeServerId = record.id;
    if (!runtime.serverOrder.includes(record.id)) {
      runtime.serverOrder.push(record.id);
    }
    await ServerInstanceStore.saveRuntime(context, runtime);
    ServerManager.applyActiveToAppStorage(record.info);
    return record.info;
  }

  static async updateActiveServerName(context: common.Context, name: string): Promise<void> {
    const active = await ServerManager.getActiveServer(context);
    if (!active) {
      return;
    }
    await ServerManager.updateServerName(context, active.id, name);
  }

  static async updateServerName(context: common.Context, id: string, name: string): Promise<void> {
    const value = name.trim();
    const current = await ServerInstanceStore.load(context, id);
    if (!current || value.length === 0) {
      return;
    }
    await ServerInstanceStore.save(context, current.id, value, current.info);
  }

  static async updateServerInfo(context: common.Context, id: string, info: StoredServerInfo): Promise<void> {
    const current = await ServerInstanceStore.load(context, id);
    if (!current) {
      return;
    }
    const saved = await ServerInstanceStore.save(context, current.id, current.name, info);
    const runtime = await ServerInstanceStore.loadRuntime(context);
    if (runtime.activeServerId === saved.id) {
      ServerManager.applyActiveToAppStorage(saved.info);
    }
  }

  static async removeActiveServer(context: common.Context): Promise<StoredServerInfo> {
    const active = await ServerManager.getActiveServer(context);
    if (!active) {
      ServerManager.applyActiveToAppStorage(StorageService.emptyServerInfo());
      return StorageService.emptyServerInfo();
    }
    return ServerManager.removeServer(context, active.id);
  }

  static async removeServer(context: common.Context, id: string): Promise<StoredServerInfo> {
    await AppSettingsStore.removeServerSettings(context, id);
    await ServerInstanceStore.remove(context, id);
    const active = await ServerManager.getActiveServer(context);
    const info = active ? active.info : StorageService.emptyServerInfo();
    ServerManager.applyActiveToAppStorage(info);
    return info;
  }

  static async clearAll(context: common.Context): Promise<void> {
    const records = await ServerInstanceStore.list(context);
    for (let i = 0; i < records.length; i++) {
      await AppSettingsStore.removeServerSettings(context, records[i].id);
    }
    await ServerInstanceStore.clearAll(context);
    ServerManager.applyActiveToAppStorage(StorageService.emptyServerInfo());
  }

  static applyActiveToAppStorage(info: StoredServerInfo): void {
    ServerManager.setAppStorage<string>('haBaseUrl', info.baseUrl);
    ServerManager.setAppStorage<string>('haAccessToken', info.accessToken);
    ServerManager.setAppStorage<string>('haRefreshToken', info.refreshToken);
    ServerManager.setAppStorage<string>('haWebhookId', info.webhookId);
    ServerManager.setAppStorage<string>('haWebhookSecret', info.webhookSecret);
    ServerManager.setAppStorage<string>('haCloudhookUrl', info.cloudhookUrl);
    ServerManager.setAppStorage<string>('haRemoteUiUrl', info.remoteUiUrl);
    ServerManager.setAppStorage<string>('haMobileAppDeviceId', info.mobileAppDeviceId);
  }

  private static getActiveServerSync(context: common.Context): ManagedServer | undefined {
    const runtime = ServerInstanceStore.loadRuntimeSync(context);
    if (runtime.activeServerId.length > 0) {
      const active = ServerInstanceStore.loadSync(context, runtime.activeServerId);
      if (active) {
        return ServerManager.managedServer(active);
      }
    }
    for (let i = runtime.serverOrder.length - 1; i >= 0; i--) {
      const record = ServerInstanceStore.loadSync(context, runtime.serverOrder[i]);
      if (record) {
        return ServerManager.managedServer(record);
      }
    }
    return undefined;
  }

  private static async findActiveServer(context: common.Context, runtime: ServerRuntimeState): Promise<ServerInstanceRecord | undefined> {
    if (runtime.activeServerId.length > 0) {
      const active = await ServerInstanceStore.load(context, runtime.activeServerId);
      if (active) {
        return active;
      }
    }
    const records = await ServerInstanceStore.list(context);
    return records.length > 0 ? records[records.length - 1] : undefined;
  }

  private static async findExistingServerByBaseUrl(context: common.Context, baseUrl: string): Promise<ServerInstanceRecord | undefined> {
    const target = ServerManager.normalizeBaseUrl(baseUrl);
    if (target.length === 0) {
      return undefined;
    }
    const records = await ServerInstanceStore.list(context);
    return records.find((server: ServerInstanceRecord): boolean => {
      return ServerManager.normalizeBaseUrl(server.info.baseUrl) === target;
    });
  }

  private static async deduplicateServersByBaseUrl(
    context: common.Context,
    records: ServerInstanceRecord[],
    runtime: ServerRuntimeState
  ): Promise<ServerInstanceRecord[]> {
    const kept: ServerInstanceRecord[] = [];
    const removedIds: string[] = [];
    for (let i = 0; i < records.length; i++) {
      const current = records[i];
      const currentKey = ServerManager.normalizeBaseUrl(current.info.baseUrl);
      if (currentKey.length === 0) {
        continue;
      }
      const existingIndex = kept.findIndex((item: ServerInstanceRecord): boolean => {
        return ServerManager.normalizeBaseUrl(item.info.baseUrl) === currentKey;
      });
      if (existingIndex < 0) {
        kept.push(current);
        continue;
      }
      const existing = kept[existingIndex];
      const keepCurrent = current.id === runtime.activeServerId ||
        (existing.id !== runtime.activeServerId && current.updatedAt > existing.updatedAt);
      if (keepCurrent) {
        removedIds.push(existing.id);
        kept[existingIndex] = current;
      } else {
        removedIds.push(current.id);
      }
    }
    if (removedIds.length === 0) {
      return kept;
    }
    for (let i = 0; i < removedIds.length; i++) {
      await ServerManager.removeServer(context, removedIds[i]);
    }
    const nextRuntime = await ServerInstanceStore.loadRuntime(context);
    if (nextRuntime.activeServerId.length === 0 && kept.length > 0) {
      nextRuntime.activeServerId = kept[kept.length - 1].id;
      await ServerInstanceStore.saveRuntime(context, nextRuntime);
    }
    return kept.filter((record: ServerInstanceRecord): boolean => !removedIds.includes(record.id));
  }

  private static managedServer(record: ServerInstanceRecord): ManagedServer {
    const server = new ManagedServerPayload();
    server.id = record.id;
    server.name = record.name;
    server.info = record.info;
    server.createdAt = record.createdAt;
    server.updatedAt = record.updatedAt;
    return server;
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

  private static normalizeBaseUrl(value: string): string {
    return value.trim().replace(/\/+$/, '');
  }

  private static setAppStorage<T>(key: string, value: T): void {
    if (!AppStorage.set<T>(key, value)) {
      AppStorage.setOrCreate<T>(key, value);
    }
  }
}
