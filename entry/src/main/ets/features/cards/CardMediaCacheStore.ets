import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import { relationalStore } from '@kit.ArkData';
import { CoverImageService, CoverPalette } from '../../services/CoverImageService';
import { CardDataStore } from './CardDataStore';

export interface CardCachedAsset {
  cacheKey: string;
  remoteUrl: string;
  localUrl: string;
  palette: CoverPalette;
}

class CardCachedAssetPayload implements CardCachedAsset {
  cacheKey: string = '';
  remoteUrl: string = '';
  localUrl: string = '';
  palette: CoverPalette = CoverImageService.FALLBACK_PALETTE;
}

export class CardMediaCacheStore {
  private static readonly TABLE: string = 'card_asset_cache';

  static async prepareCover(
    context: common.Context,
    formId: string,
    serverInstanceId: string,
    cardType: string,
    remoteUrl: string,
    accessToken: string = '',
    forceReload: boolean = false
  ): Promise<CardCachedAsset> {
    await CardMediaCacheStore.ensureSchema(context);
    const normalizedUrl = remoteUrl.trim();
    if (normalizedUrl.length === 0) {
      await CardMediaCacheStore.clearByForm(context, formId);
      return new CardCachedAssetPayload();
    }
    const cacheKey = CardMediaCacheStore.cacheKey(formId, serverInstanceId, normalizedUrl);
    const cached = await CardMediaCacheStore.loadCachedAsset(context, cacheKey, normalizedUrl);
    if (!forceReload && cached.localUrl.length > 0) {
      return cached;
    }
    let header: Record<string, string> | undefined = undefined;
    if (accessToken.trim().length > 0) {
      header = {};
      header['Authorization'] = `Bearer ${accessToken.trim()}`;
    }
    const downloadKey = forceReload ? `${cacheKey}_${Date.now()}` : cacheKey;
    const localUrl = await CoverImageService.cacheCover(context, normalizedUrl, downloadKey, header);
    if (localUrl.length === 0) {
      return cached;
    }
    const palette = await CoverImageService.extractPalette(localUrl);
    await CardMediaCacheStore.clearByForm(context, formId);
    try {
      const store = await CardDataStore.getStore(context);
      await store.insert(CardMediaCacheStore.TABLE, {
        'cache_key': cacheKey,
        'form_id': formId.trim(),
        'server_instance_id': serverInstanceId.trim(),
        'card_type': cardType.trim(),
        'asset_type': 'cover',
        'remote_url': normalizedUrl,
        'local_url': localUrl,
        'updated_at': Date.now(),
        'expires_at': 0
      }, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
    } catch (error) {
      throw CardMediaCacheStore.errorFrom(error);
    }
    const asset = new CardCachedAssetPayload();
    asset.cacheKey = cacheKey;
    asset.remoteUrl = normalizedUrl;
    asset.localUrl = localUrl;
    asset.palette = palette;
    return asset;
  }

  static async clearByForm(context: common.Context, formId: string): Promise<void> {
    await CardMediaCacheStore.ensureSchema(context);
    await CardMediaCacheStore.clearWhere(context, 'form_id = ?', [formId.trim()]);
  }

  static async clearByServer(context: common.Context, serverInstanceId: string): Promise<void> {
    await CardMediaCacheStore.ensureSchema(context);
    await CardMediaCacheStore.clearWhere(context, 'server_instance_id = ?', [serverInstanceId.trim()]);
  }

  private static async clearWhere(context: common.Context, where: string, args: relationalStore.ValueType[]): Promise<void> {
    const localUrls: string[] = [];
    try {
      const store = await CardDataStore.getStore(context);
      const result = store.querySqlSync(`SELECT local_url FROM ${CardMediaCacheStore.TABLE} WHERE ${where}`, args);
      try {
        if (result.goToFirstRow()) {
          do {
            localUrls.push(result.getString(0));
          } while (result.goToNextRow());
        }
      } finally {
        CardMediaCacheStore.closeResult(result);
      }
      for (let i = 0; i < localUrls.length; i++) {
        CardMediaCacheStore.removeLocalFile(localUrls[i]);
      }
      await store.executeSql(`DELETE FROM ${CardMediaCacheStore.TABLE} WHERE ${where}`, args);
    } catch (error) {
      throw CardMediaCacheStore.errorFrom(error);
    }
  }

  private static async loadCachedAsset(context: common.Context, cacheKey: string, remoteUrl: string): Promise<CardCachedAsset> {
    const asset = new CardCachedAssetPayload();
    try {
      const store = await CardDataStore.getStore(context);
      const result = store.querySqlSync(
        `SELECT local_url FROM ${CardMediaCacheStore.TABLE} WHERE cache_key = ? AND remote_url = ?`,
        [cacheKey, remoteUrl]
      );
      try {
        if (!result.goToFirstRow()) {
          return asset;
        }
        const localUrl = result.getString(0);
        const path = CardMediaCacheStore.localPath(localUrl);
        if (path.length === 0 || !fs.accessSync(path)) {
          return asset;
        }
        asset.cacheKey = cacheKey;
        asset.remoteUrl = remoteUrl;
        asset.localUrl = localUrl;
        asset.palette = await CoverImageService.extractPalette(localUrl);
        return asset;
      } finally {
        CardMediaCacheStore.closeResult(result);
      }
    } catch (_) {
      return new CardCachedAssetPayload();
    }
  }

  private static async ensureSchema(context: common.Context): Promise<void> {
    try {
      const store = await CardDataStore.getStore(context);
      await store.executeSql(
        'CREATE TABLE IF NOT EXISTS card_asset_cache (' +
          'cache_key TEXT PRIMARY KEY, ' +
          'form_id TEXT NOT NULL, ' +
          'server_instance_id TEXT NOT NULL, ' +
          'card_type TEXT NOT NULL, ' +
          'asset_type TEXT NOT NULL, ' +
          'remote_url TEXT NOT NULL, ' +
          'local_url TEXT NOT NULL, ' +
          'updated_at INTEGER NOT NULL, ' +
          'expires_at INTEGER)'
      );
      await CardMediaCacheStore.ensureColumn(store, 'expires_at', 'INTEGER');
      await store.executeSql('CREATE INDEX IF NOT EXISTS idx_card_asset_form ON card_asset_cache(form_id)');
      await store.executeSql('CREATE INDEX IF NOT EXISTS idx_card_asset_server ON card_asset_cache(server_instance_id)');
      await store.executeSql('CREATE INDEX IF NOT EXISTS idx_card_asset_expires ON card_asset_cache(expires_at)');
    } catch (error) {
      throw CardMediaCacheStore.errorFrom(error);
    }
  }

  private static async ensureColumn(store: relationalStore.RdbStore, column: string, definition: string): Promise<void> {
    try {
      const result = store.querySqlSync(`PRAGMA table_info(${CardMediaCacheStore.TABLE})`);
      try {
        if (result.goToFirstRow()) {
          do {
            if (result.getString(1) === column) {
              return;
            }
          } while (result.goToNextRow());
        }
      } finally {
        CardMediaCacheStore.closeResult(result);
      }
      await store.executeSql(`ALTER TABLE ${CardMediaCacheStore.TABLE} ADD COLUMN ${column} ${definition}`);
    } catch (error) {
      throw CardMediaCacheStore.errorFrom(error);
    }
  }

  private static cacheKey(formId: string, serverInstanceId: string, remoteUrl: string): string {
    return `${CardMediaCacheStore.safeKey(formId)}_${CardMediaCacheStore.safeKey(serverInstanceId)}_${CardMediaCacheStore.stableHash(remoteUrl)}`;
  }

  private static removeLocalFile(localUrl: string): void {
    const path = CardMediaCacheStore.localPath(localUrl);
    if (path.length === 0) {
      return;
    }
    try {
      if (fs.accessSync(path)) {
        fs.unlinkSync(path);
      }
    } catch (_) {
    }
  }

  private static localPath(value: string): string {
    const url = value.trim();
    if (url.startsWith('file://')) {
      return url.substring(7);
    }
    return '';
  }

  private static safeKey(value: string): string {
    const source = value.trim().length > 0 ? value.trim() : 'card';
    let result = '';
    for (let i = 0; i < source.length; i++) {
      const code = source.charCodeAt(i);
      const valid = (code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
      result += valid ? source.charAt(i) : '_';
    }
    return result.length > 0 ? result : 'card';
  }

  private static stableHash(value: string): string {
    let hash = 5381;
    for (let i = 0; i < value.length; i++) {
      hash = ((hash << 5) + hash + value.charCodeAt(i)) & 0x7FFFFFFF;
    }
    return hash.toString(16);
  }

  private static closeResult(result: relationalStore.ResultSet): void {
    try {
      result.close();
    } catch (_) {
    }
  }

  private static errorFrom(error: Error): Error {
    return error;
  }
}
