// Runtime coordinator for HarmonyOS service cards.
// It ties form lifecycle events, Home Assistant entity state, media cache, and form updates together.
import common from '@ohos.app.ability.common';
import fs from '@ohos.file.fs';
import { formBindingData, formProvider } from '@kit.FormKit';
import { CoverImageService } from '../../services/CoverImageService';
import { HaConnectionPolicyService } from '../../services/HaConnectionPolicyService';
import { HaMediaPlayerEntity } from '../../services/HaApiService';
import { AppSettingsStore } from '../../services/AppSettingsStore';
import { ServerAuthRepository } from '../../services/ServerAuthRepository';
import { UrlService } from '../../services/UrlService';
import { Localization } from '../../shared/i18n/Localization';
import { CardBindingRecord, CardDataStore, CardType, HaEntityCatalogRecord } from './CardDataStore';
import { CardFormSnapshotStore } from './CardFormSnapshotStore';
import { CardMediaCacheStore } from './CardMediaCacheStore';

interface LightFormData {
  formId: string;
  bound: boolean;
  targetId: string;
  serverInstanceId: string;
  openEntityDetailEnabled: boolean;
  title: string;
  subtitle: string;
  state: string;
  updateFrequency: string;
}

interface SceneFormData {
  formId: string;
  bound: boolean;
  targetId: string;
  serverInstanceId: string;
  openEntityDetailEnabled: boolean;
  title: string;
  subtitle: string;
  state: string;
  updateFrequency: string;
}

interface MediaFormData {
  formId: string;
  bound: boolean;
  targetId: string;
  serverInstanceId: string;
  openEntityDetailEnabled: boolean;
  title: string;
  subtitle: string;
  state: string;
  mediaTitle: string;
  mediaArtist: string;
  appName: string;
  coverUrl: string;
  coverImageName: string;
  surfaceColor: string;
  primaryTextColor: string;
  secondaryTextColor: string;
  disabledTextColor: string;
  trackColor: string;
  updateFrequency: string;
  formImages: Record<string, number>;
}

interface CardRenderedRecord {
  record: CardBindingRecord;
  data: Object;
}

export class CardRuntimeSource {
  static readonly USER_OPTIMISTIC: string = 'user_optimistic';
  static readonly API_CONFIRMED: string = 'api_confirmed';
  static readonly WEBSOCKET_PUSH: string = 'websocket_push';
  static readonly SYSTEM_REFRESH: string = 'system_refresh';
  static readonly BIND_INITIAL: string = 'bind_initial';
  static readonly ROLLBACK: string = 'rollback';
}

export class CardRuntimeCoordinator {
  private static commitChains: Map<string, Promise<CardBindingRecord>> = new Map();

  static async submit(
    context: common.Context,
    formId: string,
    cardType: string,
    record: CardBindingRecord,
    source: string,
    force: boolean = false
  ): Promise<CardBindingRecord> {
    const key = formId.trim();
    const nextRecord = CardRuntimeCoordinator.copyRecord(record);
    nextRecord.formId = key;
    nextRecord.cardType = cardType.trim().length > 0 ? cardType.trim() : nextRecord.cardType;
    nextRecord.updatedAt = Date.now();
    const previous = CardRuntimeCoordinator.commitChains.get(key) ?? Promise.resolve(CardDataStore.emptyRecord(cardType));
    const next = previous
      .catch((): CardBindingRecord => CardDataStore.emptyRecord(cardType))
      .then((): Promise<CardBindingRecord> =>
        CardRuntimeCoordinator.commitNow(context, key, nextRecord.cardType, nextRecord, source, force));
    CardRuntimeCoordinator.commitChains.set(key, next);
    try {
      return await next;
    } finally {
      if (CardRuntimeCoordinator.commitChains.get(key) === next) {
        CardRuntimeCoordinator.commitChains.delete(key);
      }
    }
  }

  static submitOptimistic(
    context: common.Context,
    formId: string,
    cardType: string,
    record: CardBindingRecord
  ): CardBindingRecord {
    record.updatedAt = Date.now();
    CardRuntimeCoordinator.submit(context, formId, cardType, record, CardRuntimeSource.USER_OPTIMISTIC).catch((): void => {});
    return record;
  }

  static async rollbackIfCurrent(
    context: common.Context,
    formId: string,
    cardType: string,
    optimistic: CardBindingRecord,
    fallback: CardBindingRecord
  ): Promise<void> {
    const key = formId.trim();
    const previous = CardRuntimeCoordinator.commitChains.get(key) ?? Promise.resolve(CardDataStore.emptyRecord(cardType));
    const next = previous
      .catch((): CardBindingRecord => CardDataStore.emptyRecord(cardType))
      .then(async (): Promise<CardBindingRecord> => {
        const current = await CardDataStore.loadBinding(context, key);
        if (CardRuntimeCoordinator.businessSignature(current) === CardRuntimeCoordinator.businessSignature(optimistic)) {
          return CardRuntimeCoordinator.commitNow(context, key, cardType, fallback, CardRuntimeSource.ROLLBACK, true);
        }
        return current;
      });
    CardRuntimeCoordinator.commitChains.set(key, next);
    try {
      await next;
    } finally {
      if (CardRuntimeCoordinator.commitChains.get(key) === next) {
        CardRuntimeCoordinator.commitChains.delete(key);
      }
    }
  }

  static async renderForm(
    context: common.Context,
    formId: string,
    cardType: string,
    record: CardBindingRecord
  ): Promise<void> {
    const rendered = await CardRuntimeCoordinator.renderRecord(context, formId.trim(), cardType, record);
    CardFormSnapshotStore.save(context, formId.trim(), rendered.data);
    await CardRuntimeCoordinator.updateForm(formId.trim(), rendered.data);
  }

  static mediaBusinessJson(entity: HaMediaPlayerEntity): string {
    return JSON.stringify({
      'mediaTitle': entity.mediaTitle,
      'mediaArtist': entity.mediaArtist,
      'appName': entity.appName,
      'entityPicture': entity.entityPicture
    });
  }

  static async applyCatalogMetadata(context: common.Context, record: CardBindingRecord): Promise<CardBindingRecord> {
    const catalog: HaEntityCatalogRecord = await CardDataStore.loadEntityCatalog(context, record.serverInstanceId, record.targetId);
    if (catalog.entityId.length === 0) {
      return record;
    }
    record.targetName = catalog.entityName.length > 0 ? catalog.entityName : record.targetName;
    record.areaId = catalog.areaId;
    record.areaName = catalog.areaName;
    return record;
  }

  private static async commitNow(
    context: common.Context,
    formId: string,
    cardType: string,
    record: CardBindingRecord,
    _source: string,
    force: boolean
  ): Promise<CardBindingRecord> {
    if (!CardDataStore.hasBinding(record)) {
      await CardRuntimeCoordinator.renderForm(context, formId, cardType, CardDataStore.emptyRecord(cardType));
      return record;
    }
    const current = await CardDataStore.loadBinding(context, formId);
    const currentSignature = CardRuntimeCoordinator.businessSignature(current);
    const nextSignature = CardRuntimeCoordinator.businessSignature(record);
    if (!force && currentSignature.length > 0 && currentSignature === nextSignature) {
      return current;
    }
    const rendered = await CardRuntimeCoordinator.renderRecord(context, formId, cardType, record);
    const nextRecord = rendered.record;
    nextRecord.updatedAt = Date.now();
    await CardDataStore.upsertBinding(context, nextRecord);
    CardFormSnapshotStore.save(context, formId, rendered.data);
    await CardRuntimeCoordinator.updateForm(formId, rendered.data);
    return nextRecord;
  }

  private static async updateForm(formId: string, data: Object): Promise<void> {
    try {
      await formProvider.updateForm(formId, formBindingData.createFormBindingData(data));
    } catch (error) {
      throw CardRuntimeCoordinator.errorFrom(error);
    }
  }

  private static async renderRecord(
    context: common.Context,
    formId: string,
    cardType: string,
    record: CardBindingRecord
  ): Promise<CardRenderedRecord> {
    const nextRecord = CardRuntimeCoordinator.copyRecord(record);
    nextRecord.formId = formId;
    nextRecord.cardType = cardType;
    if (cardType === CardType.MEDIA) {
      nextRecord.displayJson = await CardRuntimeCoordinator.mediaRenderJson(context, nextRecord);
      return {
        record: nextRecord,
        data: await CardRuntimeCoordinator.mediaFormData(context, formId, nextRecord)
      };
    }
    if (cardType === CardType.SCENE) {
      return {
        record: nextRecord,
        data: await CardRuntimeCoordinator.sceneFormData(context, formId, nextRecord)
      };
    }
    return {
      record: nextRecord,
      data: await CardRuntimeCoordinator.lightFormData(context, formId, nextRecord)
    };
  }

  private static businessSignature(record: CardBindingRecord): string {
    if (!CardDataStore.hasBinding(record)) {
      return '';
    }
    if (record.cardType === CardType.MEDIA) {
      const display = CardRuntimeCoordinator.parseDisplay(record.displayJson);
      return [
        record.cardType,
        record.serverInstanceId,
        record.targetId,
        record.targetName,
        record.areaId,
        record.areaName,
        record.state,
        CardRuntimeCoordinator.displayField(display, 'mediaTitle', ''),
        CardRuntimeCoordinator.displayField(display, 'mediaArtist', ''),
        CardRuntimeCoordinator.displayField(display, 'appName', ''),
        CardRuntimeCoordinator.displayField(display, 'entityPicture', '')
      ].join('|');
    }
    return [
      record.cardType,
      record.serverInstanceId,
      record.targetId,
      record.targetName,
      record.areaId,
      record.areaName,
      record.state
    ].join('|');
  }

  private static async mediaRenderJson(context: common.Context, record: CardBindingRecord): Promise<string> {
    const display = CardRuntimeCoordinator.parseDisplay(record.displayJson);
    const entityPicture = CardRuntimeCoordinator.displayField(display, 'entityPicture', '');
    const policy = await HaConnectionPolicyService.resolveServerBaseUrl(context, record.serverInstanceId);
    const remoteUrl = policy.allowed ? CardRuntimeCoordinator.remoteCoverUrl(policy.baseUrl, entityPicture, record.targetId) : '';
    const accessToken = policy.allowed
      ? await CardRuntimeCoordinator.coverAccessToken(context, record.serverInstanceId, policy.baseUrl, remoteUrl)
      : '';
    const asset = await CardMediaCacheStore.prepareCover(
      context,
      record.formId,
      record.serverInstanceId,
      record.cardType,
      remoteUrl,
      accessToken
    );
    return JSON.stringify({
      'mediaTitle': CardRuntimeCoordinator.displayField(display, 'mediaTitle', record.targetName),
      'mediaArtist': CardRuntimeCoordinator.displayField(display, 'mediaArtist', record.areaName),
      'appName': CardRuntimeCoordinator.displayField(display, 'appName', ''),
      'entityPicture': entityPicture,
      'coverUrl': asset.localUrl,
      'surfaceColor': asset.palette.surfaceColor,
      'primaryTextColor': asset.palette.primaryTextColor,
      'secondaryTextColor': asset.palette.secondaryTextColor,
      'disabledTextColor': asset.palette.disabledTextColor,
      'trackColor': asset.palette.trackColor
    });
  }

  private static async lightFormData(context: common.Context, formId: string, record: CardBindingRecord): Promise<LightFormData> {
    const bound = CardDataStore.hasBinding(record) && record.cardType === CardType.LIGHT;
    return {
      formId,
      bound,
      targetId: bound ? record.targetId : '',
      serverInstanceId: bound ? record.serverInstanceId : '',
      openEntityDetailEnabled: bound,
      title: bound ? record.targetName : Localization.t('card_light_control_title'),
      subtitle: bound ? CardRuntimeCoordinator.lightSubtitle(record) : Localization.t('card_bind_light_device'),
      state: bound ? record.state : 'unknown',
      updateFrequency: await AppSettingsStore.loadServiceCardUpdateFrequency(context)
    };
  }

  private static async sceneFormData(context: common.Context, formId: string, record: CardBindingRecord): Promise<SceneFormData> {
    const bound = CardDataStore.hasBinding(record) && record.cardType === CardType.SCENE;
    return {
      formId,
      bound,
      targetId: bound ? record.targetId : '',
      serverInstanceId: bound ? record.serverInstanceId : '',
      openEntityDetailEnabled: false,
      title: bound ? record.targetName : Localization.t('card_scene_control_title'),
      subtitle: bound ? CardRuntimeCoordinator.sceneFeedbackText(record.state) : Localization.t('card_bind_scene'),
      state: bound ? record.state : 'unknown',
      updateFrequency: await AppSettingsStore.loadServiceCardUpdateFrequency(context)
    };
  }

  private static async mediaFormData(context: common.Context, formId: string, record: CardBindingRecord): Promise<MediaFormData> {
    const bound = CardDataStore.hasBinding(record) && record.cardType === CardType.MEDIA;
    const display = CardRuntimeCoordinator.parseDisplay(record.displayJson);
    const data: MediaFormData = {
      formId,
      bound,
      targetId: bound ? record.targetId : '',
      serverInstanceId: bound ? record.serverInstanceId : '',
      openEntityDetailEnabled: bound,
      title: bound ? record.targetName : Localization.t('card_media_control_title'),
      subtitle: bound ? CardRuntimeCoordinator.mediaSubtitle(record, display) : Localization.t('card_bind_media_player'),
      state: bound ? record.state : 'unknown',
      mediaTitle: bound ? CardRuntimeCoordinator.displayField(display, 'mediaTitle', record.targetName) : Localization.t('card_choose_player'),
      mediaArtist: bound ? CardRuntimeCoordinator.displayField(display, 'mediaArtist', record.areaName) : '',
      appName: CardRuntimeCoordinator.displayField(display, 'appName', ''),
      coverUrl: CardRuntimeCoordinator.displayField(display, 'coverUrl', ''),
      coverImageName: '',
      surfaceColor: bound ? CardRuntimeCoordinator.displayField(display, 'surfaceColor', CoverImageService.FALLBACK_PALETTE.surfaceColor) : '#FFFFFF',
      primaryTextColor: CardRuntimeCoordinator.displayField(display, 'primaryTextColor', CoverImageService.FALLBACK_PALETTE.primaryTextColor),
      secondaryTextColor: CardRuntimeCoordinator.displayField(display, 'secondaryTextColor', CoverImageService.FALLBACK_PALETTE.secondaryTextColor),
      disabledTextColor: CardRuntimeCoordinator.displayField(display, 'disabledTextColor', CoverImageService.FALLBACK_PALETTE.disabledTextColor),
      trackColor: CardRuntimeCoordinator.displayField(display, 'trackColor', CoverImageService.FALLBACK_PALETTE.trackColor),
      updateFrequency: await AppSettingsStore.loadServiceCardUpdateFrequency(context),
      formImages: {}
    };
    CardRuntimeCoordinator.attachCoverImage(formId, data);
    return data;
  }

  private static attachCoverImage(formId: string, data: MediaFormData): void {
    const path = data.coverUrl.startsWith('file://') ? data.coverUrl.substring(7) : '';
    if (path.length === 0) {
      return;
    }
    try {
      if (!fs.accessSync(path)) {
        data.coverUrl = '';
        return;
      }
      const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const imageName = `music_cover_${formId.replace(/[^A-Za-z0-9_]/g, '_')}_${CardRuntimeCoordinator.stableHash(data.coverUrl)}`;
      data.coverImageName = imageName;
      data.formImages[imageName] = file.fd;
    } catch (_) {
      data.coverUrl = '';
    }
  }

  private static copyRecord(record: CardBindingRecord): CardBindingRecord {
    return {
      formId: record.formId,
      formName: record.formName,
      formDimension: record.formDimension,
      cardType: record.cardType,
      serverInstanceId: record.serverInstanceId,
      targetType: record.targetType,
      targetId: record.targetId,
      targetName: record.targetName,
      areaId: record.areaId,
      areaName: record.areaName,
      configJson: record.configJson,
      state: record.state,
      displayJson: record.displayJson,
      updatedAt: record.updatedAt
    };
  }

  private static remoteCoverUrl(baseUrl: string, entityPicture: string, entityId: string): string {
    const picture = entityPicture.trim();
    if (picture.length === 0 || picture.startsWith('file://')) {
      return picture;
    }
    if (UrlService.isHttpLikeUrl(picture)) {
      if (CardRuntimeCoordinator.isSameEndpoint(baseUrl, picture)) {
        return picture;
      }
      if (CardRuntimeCoordinator.isPrivateOrLocalUrl(picture)) {
        return CardRuntimeCoordinator.mediaProxyUrl(baseUrl, entityId, picture);
      }
      return picture;
    }
    return picture.startsWith('/') ? `${baseUrl.trim().replace(/\/+$/, '')}${picture}` : picture;
  }

  private static mediaProxyUrl(baseUrl: string, entityId: string, entityPicture: string): string {
    const normalizedBase = baseUrl.trim().replace(/\/+$/, '');
    const normalizedEntity = entityId.trim();
    if (normalizedBase.length === 0 || normalizedEntity.length === 0) {
      return '';
    }
    return `${normalizedBase}/api/media_player_proxy/${encodeURIComponent(normalizedEntity)}?cache=${CardRuntimeCoordinator.stableHash(entityPicture)}`;
  }

  private static async coverAccessToken(
    context: common.Context,
    serverInstanceId: string,
    baseUrl: string,
    remoteUrl: string
  ): Promise<string> {
    if (!CardRuntimeCoordinator.isSameEndpoint(baseUrl, remoteUrl)) {
      return '';
    }
    try {
      const session = await ServerAuthRepository.loadFreshWithBaseUrl(context, serverInstanceId, baseUrl);
      return session.accessToken;
    } catch (_) {
      return '';
    }
  }

  private static isSameEndpoint(baseUrl: string, remoteUrl: string): boolean {
    if (!UrlService.isHttpLikeUrl(baseUrl) || !UrlService.isHttpLikeUrl(remoteUrl)) {
      return false;
    }
    return UrlService.endpointKey(baseUrl) === UrlService.endpointKey(remoteUrl);
  }

  private static isPrivateOrLocalUrl(url: string): boolean {
    const host = CardRuntimeCoordinator.hostFromUrl(url);
    if (host === 'localhost' || host === '127.0.0.1' || host.endsWith('.local')) {
      return true;
    }
    if (host.startsWith('192.168.') || host.startsWith('10.')) {
      return true;
    }
    if (!host.startsWith('172.')) {
      return false;
    }
    const secondPart = host.split('.')[1];
    const secondOctet = Number(secondPart);
    return secondOctet >= 16 && secondOctet <= 31;
  }

  private static hostFromUrl(url: string): string {
    const schemeIndex = url.indexOf('://');
    if (schemeIndex < 0) {
      return '';
    }
    const hostStart = schemeIndex + 3;
    let hostEnd = url.indexOf('/', hostStart);
    if (hostEnd < 0) {
      hostEnd = url.indexOf('?', hostStart);
    }
    if (hostEnd < 0) {
      hostEnd = url.length;
    }
    const authority = url.substring(hostStart, hostEnd);
    const host = authority.indexOf('@') >= 0 ? authority.substring(authority.lastIndexOf('@') + 1) : authority;
    const portIndex = host.lastIndexOf(':');
    return (portIndex > 0 ? host.substring(0, portIndex) : host).toLowerCase();
  }

  private static stableHash(value: string): string {
    let hash = 5381;
    for (let i = 0; i < value.length; i++) {
      hash = ((hash << 5) + hash + value.charCodeAt(i)) & 0x7FFFFFFF;
    }
    return hash.toString(16);
  }

  private static parseDisplay(raw: string): Record<string, string> {
    try {
      return JSON.parse(raw) as Record<string, string>;
    } catch (_) {
      return {};
    }
  }

  private static displayField(display: Record<string, string>, key: string, fallback: string): string {
    const value = display[key];
    return typeof value === 'string' && value.length > 0 ? value : fallback;
  }

  private static errorFrom(error: Error): Error {
    return error;
  }

  private static lightSubtitle(record: CardBindingRecord): string {
    return `${CardRuntimeCoordinator.lightStateText(record.state)} | ${CardRuntimeCoordinator.areaText(record.areaName)}`;
  }

  private static sceneFeedbackText(state: string): string {
    if (state.startsWith('scene_activated')) {
      return Localization.t('card_scene_activated');
    }
    if (state.startsWith('scene_failed')) {
      return Localization.t('card_scene_failed');
    }
    return '';
  }

  private static areaText(areaName: string): string {
    const value = areaName.trim();
    return value.length > 0 ? value : Localization.t('state_unknown');
  }

  private static lightStateText(state: string): string {
    if (state === 'on') {
      return Localization.t('state_on');
    }
    if (state === 'off') {
      return Localization.t('state_off');
    }
    return Localization.t('state_unknown');
  }

  private static mediaSubtitle(record: CardBindingRecord, display: Record<string, string>): string {
    const appName = CardRuntimeCoordinator.displayField(display, 'appName', '');
    return appName.length > 0 ? `${CardRuntimeCoordinator.mediaStateText(record.state)} | ${appName}` : CardRuntimeCoordinator.mediaStateText(record.state);
  }

  private static mediaStateText(state: string): string {
    if (state === 'playing') {
      return Localization.t('state_playing');
    }
    if (state === 'paused') {
      return Localization.t('state_paused');
    }
    if (state === 'idle') {
      return Localization.t('state_idle');
    }
    if (state === 'off') {
      return Localization.t('state_off');
    }
    return Localization.t('state_unknown');
  }

}
