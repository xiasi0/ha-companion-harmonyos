import common from '@ohos.app.ability.common';
import { formBindingData } from '@kit.FormKit';
import { AppSettingsStore } from '../../services/AppSettingsStore';
import { HaConnectionPolicyService } from '../../services/HaConnectionPolicyService';
import { HaApiService, HaCameraEntity, HaLightActionResult, HaMediaPlayerEntity } from '../../services/HaApiService';
import { ServerAuthRepository, ServerAuthSession } from '../../services/ServerAuthRepository';
import { CardBindingRecord, CardDataStore, CardTargetType, CardType, HaEntityCatalogRecord } from './CardDataStore';
import { CardEventGate } from './CardEventGate';
import { CardFormSnapshotStore } from './CardFormSnapshotStore';
import { CardFormWantParser } from './CardFormWantParser';
import { CardMediaCacheStore } from './CardMediaCacheStore';
import { CARD_TICK_REFRESH_EVENT } from './CardRuntimeEvents';
import { CardRuntimeCoordinator, CardRuntimeSource } from './CardRuntimeCoordinator';

interface FormIdData {
  formId: string;
}

export class CardRuntimeRepository {
  static addForm(context: common.Context, formId: string, formName: string, formDimension: string): formBindingData.FormBindingData {
    const normalizedFormId = formId.trim();
    CardDataStore.registerInstance(context, normalizedFormId, formName, formDimension, CardRuntimeRepository.cardTypeFromFormName(formName))
      .then((): Promise<void> => CardRuntimeRepository.updateForm(context, normalizedFormId))
      .catch((): void => {});
    const fallback: FormIdData = { formId };
    return formBindingData.createFormBindingData(CardFormSnapshotStore.load(context, normalizedFormId) ?? fallback);
  }

  static async updateForm(context: common.Context, formId: string): Promise<void> {
    const record = await CardDataStore.loadBinding(context, formId);
    if (record.cardType === CardType.MEDIA) {
      await CardRuntimeRepository.refreshMedia(context, formId, record, true);
      return;
    }
    if (record.cardType === CardType.CAMERA) {
      await CardRuntimeRepository.refreshCamera(context, formId, record);
      return;
    }
    if (record.cardType === CardType.SCENE) {
      await CardRuntimeRepository.refreshScene(context, formId, record, true);
      return;
    }
    await CardRuntimeRepository.refreshLight(context, formId, record, true);
  }

  static handleEvent(context: common.Context, formId: string, message: string): void {
    const event = CardFormWantParser.event(message);
    const eventKey = `${event.length > 0 ? event : 'light'}:${formId}`;
    if (!CardEventGate.tryBegin(eventKey)) {
      return;
    }
    CardDataStore.loadBinding(context, formId)
      .then((record: CardBindingRecord): Promise<void> => {
        if (event === CARD_TICK_REFRESH_EVENT) {
          return CardRuntimeRepository.refreshByTicker(context, formId, record);
        }
        if (record.cardType === CardType.CAMERA || event === 'refresh_camera') {
          return CardRuntimeRepository.refreshCamera(context, formId, record);
        }
        if (record.cardType === CardType.MEDIA || event.startsWith('media_')) {
          return CardRuntimeRepository.controlMedia(context, formId, record, event);
        }
        if (record.cardType === CardType.SCENE || event === 'activate_scene') {
          return CardRuntimeRepository.activateScene(context, formId, record);
        }
        return CardRuntimeRepository.toggleLight(context, formId, record);
      })
      .catch((): void => {})
      .finally((): void => CardEventGate.finish(eventKey));
  }

  static async removeForm(context: common.Context, formId: string): Promise<void> {
    await CardMediaCacheStore.clearByForm(context, formId);
    await CardDataStore.clear(context, formId);
    CardFormSnapshotStore.clear(context, formId);
  }

  static async refreshRegisteredForms(context: common.Context): Promise<void> {
    const light = await CardDataStore.listBindingsByType(context, CardType.LIGHT);
    for (let i = 0; i < light.length; i++) {
      await CardRuntimeRepository.refreshLight(context, light[i].formId, light[i]).catch((): void => {});
    }
    const media = await CardDataStore.listBindingsByType(context, CardType.MEDIA);
    for (let i = 0; i < media.length; i++) {
      await CardRuntimeRepository.refreshMedia(context, media[i].formId, media[i]).catch((): void => {});
    }
    const scenes = await CardDataStore.listBindingsByType(context, CardType.SCENE);
    for (let i = 0; i < scenes.length; i++) {
      await CardRuntimeRepository.refreshScene(context, scenes[i].formId, scenes[i]).catch((): void => {});
    }
    const cameras = await CardDataStore.listBindingsByType(context, CardType.CAMERA);
    for (let i = 0; i < cameras.length; i++) {
      await CardRuntimeRepository.refreshCamera(context, cameras[i].formId, cameras[i]).catch((): void => {});
    }
  }

  static async hasRegisteredForms(context: common.Context): Promise<boolean> {
    const light = await CardDataStore.listFormIdsByType(context, CardType.LIGHT);
    if (light.length > 0) {
      return true;
    }
    if ((await CardDataStore.listFormIdsByType(context, CardType.MEDIA)).length > 0) {
      return true;
    }
    if ((await CardDataStore.listFormIdsByType(context, CardType.SCENE)).length > 0) {
      return true;
    }
    return (await CardDataStore.listFormIdsByType(context, CardType.CAMERA)).length > 0;
  }

  static async listBoundEntityIds(context: common.Context, serverInstanceId: string): Promise<string[]> {
    return CardDataStore.listBoundEntityIds(context, serverInstanceId);
  }

  static async clearByServer(context: common.Context, serverInstanceId: string): Promise<void> {
    const records = await CardRuntimeRepository.recordsByServer(context, serverInstanceId);
    await CardMediaCacheStore.clearByServer(context, serverInstanceId);
    await CardDataStore.clearByServer(context, serverInstanceId);
    for (let i = 0; i < records.length; i++) {
      const record = records[i];
      await CardRuntimeCoordinator.renderForm(context, record.formId, record.cardType, CardDataStore.emptyRecord(record.cardType))
        .catch((): void => {});
    }
  }

  static async bindLightEntity(
    context: common.Context,
    formId: string,
    serverInstanceId: string,
    entityId: string,
    entityName: string,
    areaId: string,
    areaName: string,
    state: string
  ): Promise<void> {
    const current = await CardDataStore.loadBinding(context, formId);
    const record = CardDataStore.emptyRecord(CardType.LIGHT);
    record.formId = formId.trim();
    record.formName = current.formName;
    record.formDimension = current.formDimension;
    record.serverInstanceId = serverInstanceId.trim();
    record.targetType = CardTargetType.ENTITY;
    record.targetId = entityId.trim();
    record.targetName = entityName.trim();
    record.areaId = areaId.trim();
    record.areaName = areaName.trim();
    record.state = state.trim().length > 0 ? state.trim() : 'unknown';
    await CardRuntimeCoordinator.submit(context, formId, CardType.LIGHT, record, CardRuntimeSource.BIND_INITIAL, true);
  }

  static async bindMediaEntity(
    context: common.Context,
    formId: string,
    serverInstanceId: string,
    _baseUrl: string,
    entity: HaMediaPlayerEntity
  ): Promise<void> {
    const current = await CardDataStore.loadBinding(context, formId);
    const record = CardDataStore.emptyRecord(CardType.MEDIA);
    record.formId = formId.trim();
    record.formName = current.formName;
    record.formDimension = current.formDimension;
    record.serverInstanceId = serverInstanceId.trim();
    record.targetType = CardTargetType.ENTITY;
    record.targetId = entity.entityId.trim();
    record.targetName = entity.name.trim();
    record.areaName = entity.areaName.trim();
    record.state = entity.state.trim().length > 0 ? entity.state.trim() : 'unknown';
    record.displayJson = CardRuntimeCoordinator.mediaBusinessJson(entity);
    await CardRuntimeCoordinator.submit(context, formId, CardType.MEDIA, record, CardRuntimeSource.BIND_INITIAL, true);
  }

  static async bindMediaCatalogEntity(
    context: common.Context,
    formId: string,
    serverInstanceId: string,
    baseUrl: string,
    entity: HaEntityCatalogRecord
  ): Promise<void> {
    const session = await CardRuntimeRepository.loadAllowedSession(context, serverInstanceId);
    if (session.accessToken.length > 0) {
      try {
        const liveEntity = await HaApiService.fetchMediaPlayerState(session.baseUrl, session.accessToken, entity.entityId);
        await CardRuntimeRepository.bindMediaEntity(context, formId, serverInstanceId, session.baseUrl, liveEntity);
        return;
      } catch (_) {
      }
    }
    await CardRuntimeRepository.bindMediaEntity(context, formId, serverInstanceId, baseUrl, {
      entityId: entity.entityId,
      name: entity.entityName.length > 0 ? entity.entityName : entity.entityId,
      areaName: entity.areaName,
      state: entity.state.length > 0 ? entity.state : 'unknown',
      mediaTitle: entity.entityName.length > 0 ? entity.entityName : entity.entityId,
      mediaArtist: entity.areaName,
      appName: '',
      entityPicture: ''
    });
  }

  static async bindSceneEntity(
    context: common.Context,
    formId: string,
    serverInstanceId: string,
    entityId: string,
    entityName: string,
    areaId: string,
    areaName: string,
    state: string
  ): Promise<void> {
    const current = await CardDataStore.loadBinding(context, formId);
    const record = CardDataStore.emptyRecord(CardType.SCENE);
    record.formId = formId.trim();
    record.formName = current.formName;
    record.formDimension = current.formDimension;
    record.serverInstanceId = serverInstanceId.trim();
    record.targetType = CardTargetType.ENTITY;
    record.targetId = entityId.trim();
    record.targetName = entityName.trim();
    record.areaId = areaId.trim();
    record.areaName = areaName.trim();
    record.state = state.trim().length > 0 ? state.trim() : 'unknown';
    await CardRuntimeCoordinator.submit(context, formId, CardType.SCENE, record, CardRuntimeSource.BIND_INITIAL, true);
  }

  static async bindCameraCatalogEntity(
    context: common.Context,
    formId: string,
    serverInstanceId: string,
    entity: HaEntityCatalogRecord
  ): Promise<void> {
    const session = await CardRuntimeRepository.loadAllowedSession(context, serverInstanceId);
    let camera: HaCameraEntity | undefined = undefined;
    if (session.accessToken.length > 0) {
      try {
        camera = await HaApiService.fetchCameraState(session.baseUrl, session.accessToken, entity.entityId);
      } catch (_) {
      }
    }
    const current = await CardDataStore.loadBinding(context, formId);
    const record = CardDataStore.emptyRecord(CardType.CAMERA);
    record.formId = formId.trim();
    record.formName = current.formName;
    record.formDimension = current.formDimension;
    record.serverInstanceId = serverInstanceId.trim();
    record.targetType = CardTargetType.ENTITY;
    record.targetId = entity.entityId.trim();
    record.targetName = camera?.name ?? (entity.entityName.length > 0 ? entity.entityName : entity.entityId);
    record.areaId = entity.areaId;
    record.areaName = camera?.areaName ?? entity.areaName;
    record.state = camera?.state ?? (entity.state.length > 0 ? entity.state : 'unknown');
    record.displayJson = JSON.stringify({
      'entityPicture': camera?.entityPicture ?? ''
    });
    await CardRuntimeCoordinator.submit(context, formId, CardType.CAMERA, record, CardRuntimeSource.BIND_INITIAL, true);
  }

  static async syncLightState(context: common.Context, entityId: string, state: string): Promise<void> {
    const records = await CardDataStore.listBindingsByType(context, CardType.LIGHT);
    for (let i = 0; i < records.length; i++) {
      if (records[i].targetId !== entityId) {
        continue;
      }
      records[i].state = state.trim().length > 0 ? state.trim() : 'unknown';
      await CardRuntimeCoordinator.submit(context, records[i].formId, CardType.LIGHT, records[i], CardRuntimeSource.WEBSOCKET_PUSH)
        .catch((): void => {});
    }
  }

  static async syncMediaState(context: common.Context, entityId: string, entity: HaMediaPlayerEntity): Promise<void> {
    const records = await CardDataStore.listBindingsByType(context, CardType.MEDIA);
    for (let i = 0; i < records.length; i++) {
      if (records[i].targetId !== entityId) {
        continue;
      }
      records[i].state = entity.state;
      records[i].targetName = entity.name;
      records[i].areaName = entity.areaName;
      records[i] = await CardRuntimeCoordinator.applyCatalogMetadata(context, records[i]);
      records[i].displayJson = CardRuntimeCoordinator.mediaBusinessJson(entity);
      await CardRuntimeCoordinator.submit(context, records[i].formId, CardType.MEDIA, records[i], CardRuntimeSource.WEBSOCKET_PUSH)
        .catch((): void => {});
    }
  }

  static async syncCameraState(context: common.Context, entityId: string, entity: HaCameraEntity): Promise<void> {
    const records = await CardDataStore.listBindingsByType(context, CardType.CAMERA);
    for (let i = 0; i < records.length; i++) {
      if (records[i].targetId !== entityId) {
        continue;
      }
      records[i].state = entity.state;
      records[i].targetName = entity.name;
      records[i].areaName = entity.areaName;
      records[i] = await CardRuntimeCoordinator.applyCatalogMetadata(context, records[i]);
      records[i].displayJson = JSON.stringify({
        'entityPicture': entity.entityPicture
      });
      await CardRuntimeCoordinator.submit(context, records[i].formId, CardType.CAMERA, records[i], CardRuntimeSource.WEBSOCKET_PUSH, true)
        .catch((): void => {});
    }
  }

  private static cardTypeFromFormName(formName: string): string {
    if (formName === 'harmony_light_service_card') {
      return CardType.LIGHT;
    }
    if (formName === 'harmony_media_service_card') {
      return CardType.MEDIA;
    }
    if (formName === 'harmony_scene_service_card') {
      return CardType.SCENE;
    }
    if (formName === 'harmony_camera_service_card') {
      return CardType.CAMERA;
    }
    return formName.trim();
  }

  private static async refreshLight(
    context: common.Context,
    formId: string,
    record: CardBindingRecord,
    forceRender: boolean = false
  ): Promise<void> {
    if (!CardDataStore.hasBinding(record) || record.cardType !== CardType.LIGHT) {
      await CardRuntimeCoordinator.renderForm(context, formId, CardType.LIGHT, CardDataStore.emptyRecord(CardType.LIGHT));
      return;
    }
    const session = await CardRuntimeRepository.loadAllowedSession(context, record.serverInstanceId);
    if (session.accessToken.length === 0) {
      await CardRuntimeCoordinator.renderForm(context, formId, CardType.LIGHT, record).catch((): void => {});
      return;
    }
    let result = await HaApiService.fetchLightState(session.baseUrl, session.accessToken, record.targetId);
    if (!result.success && result.responseCode === 401) {
      const refreshed = await ServerAuthRepository.refreshWithBaseUrl(context, record.serverInstanceId, session.baseUrl);
      if (refreshed.accessToken.length > 0) {
        result = await HaApiService.fetchLightState(refreshed.baseUrl, refreshed.accessToken, record.targetId);
      }
    }
    if (result.success) {
      record.state = result.state;
      record = await CardRuntimeCoordinator.applyCatalogMetadata(context, record);
      await CardRuntimeCoordinator.submit(context, formId, CardType.LIGHT, record, CardRuntimeSource.SYSTEM_REFRESH, forceRender);
      return;
    }
    await CardRuntimeCoordinator.renderForm(context, formId, CardType.LIGHT, record);
  }

  private static async toggleLight(context: common.Context, formId: string, record: CardBindingRecord): Promise<void> {
    if (!CardDataStore.hasBinding(record) || record.cardType !== CardType.LIGHT) {
      await CardRuntimeCoordinator.renderForm(context, formId, CardType.LIGHT, CardDataStore.emptyRecord(CardType.LIGHT));
      return;
    }
    const turnOn = record.state !== 'on';
    const optimistic = CardRuntimeRepository.copyRecord(record);
    optimistic.state = turnOn ? 'on' : 'off';
    CardRuntimeCoordinator.submitOptimistic(context, formId, CardType.LIGHT, optimistic);
    const session = await CardRuntimeRepository.loadAllowedSession(context, record.serverInstanceId);
    if (session.accessToken.length === 0) {
      await CardRuntimeCoordinator.rollbackIfCurrent(context, formId, CardType.LIGHT, optimistic, record).catch((): void => {});
      return;
    }
    let result = await HaApiService.setLightState(session.baseUrl, session.accessToken, record.targetId, turnOn);
    if (!result.success && result.responseCode === 401) {
      const refreshed = await ServerAuthRepository.refreshWithBaseUrl(context, record.serverInstanceId, session.baseUrl);
      if (refreshed.accessToken.length > 0) {
        result = await HaApiService.setLightState(refreshed.baseUrl, refreshed.accessToken, record.targetId, turnOn);
      }
    }
    if (result.success) {
      const next = CardRuntimeRepository.copyRecord(record);
      next.state = result.state;
      await CardRuntimeCoordinator.submit(context, formId, CardType.LIGHT, next, CardRuntimeSource.API_CONFIRMED).catch((): void => {});
      return;
    }
    await CardRuntimeCoordinator.rollbackIfCurrent(context, formId, CardType.LIGHT, optimistic, record).catch((): void => {});
  }

  private static async refreshMedia(
    context: common.Context,
    formId: string,
    record: CardBindingRecord,
    forceRender: boolean = false
  ): Promise<void> {
    if (!CardDataStore.hasBinding(record) || record.cardType !== CardType.MEDIA) {
      await CardRuntimeCoordinator.renderForm(context, formId, CardType.MEDIA, CardDataStore.emptyRecord(CardType.MEDIA));
      return;
    }
    const session = await CardRuntimeRepository.loadAllowedSession(context, record.serverInstanceId);
    if (session.accessToken.length === 0) {
      await CardRuntimeCoordinator.renderForm(context, formId, CardType.MEDIA, record).catch((): void => {});
      return;
    }
    let activeSession = session;
    let entity: HaMediaPlayerEntity | undefined = undefined;
    try {
      entity = await HaApiService.fetchMediaPlayerState(activeSession.baseUrl, activeSession.accessToken, record.targetId);
    } catch (_) {
      const refreshed = await ServerAuthRepository.refreshWithBaseUrl(context, record.serverInstanceId, activeSession.baseUrl);
      if (refreshed.accessToken.length > 0) {
        activeSession = refreshed;
        entity = await HaApiService.fetchMediaPlayerState(activeSession.baseUrl, activeSession.accessToken, record.targetId);
      }
    }
    if (entity) {
      record.state = entity.state;
      record.targetName = entity.name;
      record.areaName = entity.areaName;
      record = await CardRuntimeCoordinator.applyCatalogMetadata(context, record);
      record.displayJson = CardRuntimeCoordinator.mediaBusinessJson(entity);
      await CardRuntimeCoordinator.submit(context, formId, CardType.MEDIA, record, CardRuntimeSource.SYSTEM_REFRESH, forceRender);
      return;
    }
    await CardRuntimeCoordinator.renderForm(context, formId, CardType.MEDIA, record);
  }

  private static async refreshScene(
    context: common.Context,
    formId: string,
    record: CardBindingRecord,
    forceRender: boolean = false
  ): Promise<void> {
    if (!CardDataStore.hasBinding(record) || record.cardType !== CardType.SCENE) {
      await CardRuntimeCoordinator.renderForm(context, formId, CardType.SCENE, CardDataStore.emptyRecord(CardType.SCENE));
      return;
    }
    record = await CardRuntimeCoordinator.applyCatalogMetadata(context, record);
    await CardRuntimeCoordinator.submit(context, formId, CardType.SCENE, record, CardRuntimeSource.SYSTEM_REFRESH, forceRender);
  }

  private static async refreshCamera(
    context: common.Context,
    formId: string,
    record: CardBindingRecord
  ): Promise<void> {
    if (!CardDataStore.hasBinding(record) || record.cardType !== CardType.CAMERA) {
      await CardRuntimeCoordinator.renderForm(context, formId, CardType.CAMERA, CardDataStore.emptyRecord(CardType.CAMERA));
      return;
    }
    const session = await CardRuntimeRepository.loadAllowedSession(context, record.serverInstanceId);
    if (session.accessToken.length === 0) {
      await CardRuntimeCoordinator.renderForm(context, formId, CardType.CAMERA, record).catch((): void => {});
      return;
    }
    let activeSession = session;
    let camera: HaCameraEntity | undefined = undefined;
    try {
      camera = await HaApiService.fetchCameraState(activeSession.baseUrl, activeSession.accessToken, record.targetId);
    } catch (_) {
      const refreshed = await ServerAuthRepository.refreshWithBaseUrl(context, record.serverInstanceId, activeSession.baseUrl);
      if (refreshed.accessToken.length > 0) {
        activeSession = refreshed;
        camera = await HaApiService.fetchCameraState(activeSession.baseUrl, activeSession.accessToken, record.targetId);
      }
    }
    if (camera) {
      record.state = camera.state;
      record.targetName = camera.name;
      record.areaName = camera.areaName;
      record = await CardRuntimeCoordinator.applyCatalogMetadata(context, record);
      record.displayJson = JSON.stringify({
        'entityPicture': camera.entityPicture
      });
      await CardRuntimeCoordinator.submit(context, formId, CardType.CAMERA, record, CardRuntimeSource.SYSTEM_REFRESH, true);
      return;
    }
    await CardRuntimeCoordinator.renderForm(context, formId, CardType.CAMERA, record);
  }

  private static async refreshByTicker(context: common.Context, formId: string, record: CardBindingRecord): Promise<void> {
    if (await AppSettingsStore.loadServiceCardUpdateFrequency(context) === 'default') {
      return;
    }
    if (record.cardType === CardType.MEDIA) {
      await CardRuntimeRepository.refreshMedia(context, formId, record);
      return;
    }
    if (record.cardType === CardType.SCENE) {
      await CardRuntimeRepository.refreshScene(context, formId, record);
      return;
    }
    if (record.cardType === CardType.CAMERA) {
      await CardRuntimeRepository.refreshCamera(context, formId, record);
      return;
    }
    await CardRuntimeRepository.refreshLight(context, formId, record);
  }

  private static async activateScene(context: common.Context, formId: string, record: CardBindingRecord): Promise<void> {
    if (!CardDataStore.hasBinding(record) || record.cardType !== CardType.SCENE) {
      await CardRuntimeCoordinator.renderForm(context, formId, CardType.SCENE, CardDataStore.emptyRecord(CardType.SCENE));
      return;
    }
    const session = await CardRuntimeRepository.loadAllowedSession(context, record.serverInstanceId);
    if (session.accessToken.length === 0) {
      await CardRuntimeRepository.showSceneFeedback(context, formId, record, false);
      return;
    }
    let result = await HaApiService.activateScene(session.baseUrl, session.accessToken, record.targetId);
    if (!result.success && result.responseCode === 401) {
      const refreshed = await ServerAuthRepository.refreshWithBaseUrl(context, record.serverInstanceId, session.baseUrl);
      if (refreshed.accessToken.length > 0) {
        result = await HaApiService.activateScene(refreshed.baseUrl, refreshed.accessToken, record.targetId);
      }
    }
    await CardRuntimeRepository.showSceneFeedback(context, formId, record, result.success);
  }

  private static async showSceneFeedback(
    context: common.Context,
    formId: string,
    record: CardBindingRecord,
    success: boolean
  ): Promise<void> {
    const feedback = CardRuntimeRepository.copyRecord(record);
    feedback.state = `${success ? 'scene_activated' : 'scene_failed'}:${Date.now()}`;
    await CardRuntimeCoordinator.submit(
      context,
      formId,
      CardType.SCENE,
      feedback,
      success ? CardRuntimeSource.API_CONFIRMED : CardRuntimeSource.ROLLBACK,
      true
    ).catch((): void => {});
    setTimeout((): void => {
      CardRuntimeCoordinator.rollbackIfCurrent(context, formId, CardType.SCENE, feedback, record)
        .catch((): void => {});
    }, 3000);
  }

  private static async controlMedia(context: common.Context, formId: string, record: CardBindingRecord, event: string): Promise<void> {
    if (!CardDataStore.hasBinding(record) || record.cardType !== CardType.MEDIA) {
      await CardRuntimeCoordinator.renderForm(context, formId, CardType.MEDIA, CardDataStore.emptyRecord(CardType.MEDIA));
      return;
    }
    const optimisticState = CardRuntimeRepository.optimisticMediaState(record.state, event);
    let optimistic: CardBindingRecord | undefined = undefined;
    if (optimisticState !== record.state) {
      optimistic = CardRuntimeRepository.copyRecord(record);
      optimistic.state = optimisticState;
      CardRuntimeCoordinator.submitOptimistic(context, formId, CardType.MEDIA, optimistic);
    }
    const session = await CardRuntimeRepository.loadAllowedSession(context, record.serverInstanceId);
    if (session.accessToken.length === 0) {
      if (optimistic) {
        await CardRuntimeCoordinator.rollbackIfCurrent(context, formId, CardType.MEDIA, optimistic, record).catch((): void => {});
      }
      return;
    }
    let result: HaLightActionResult = await HaApiService.controlMediaPlayer(session.baseUrl, session.accessToken, record.targetId, event);
    if (!result.success && result.responseCode === 401) {
      const refreshed = await ServerAuthRepository.refreshWithBaseUrl(context, record.serverInstanceId, session.baseUrl);
      if (refreshed.accessToken.length > 0) {
        result = await HaApiService.controlMediaPlayer(refreshed.baseUrl, refreshed.accessToken, record.targetId, event);
      }
    }
    if (result.success) {
      CardRuntimeRepository.scheduleMediaRefresh(context, formId, 600);
      CardRuntimeRepository.scheduleMediaRefresh(context, formId, 1600);
      CardRuntimeRepository.scheduleMediaRefresh(context, formId, 3500);
      return;
    }
    if (optimistic) {
      await CardRuntimeCoordinator.rollbackIfCurrent(context, formId, CardType.MEDIA, optimistic, record).catch((): void => {});
    }
  }

  private static scheduleMediaRefresh(context: common.Context, formId: string, delayMs: number): void {
    const normalizedFormId = formId.trim();
    if (normalizedFormId.length === 0) {
      return;
    }
    setTimeout((): void => {
      CardDataStore.loadBinding(context, normalizedFormId)
        .then((latest: CardBindingRecord): Promise<void> =>
          CardRuntimeRepository.refreshMedia(context, normalizedFormId, latest))
        .catch((): void => {});
    }, delayMs);
  }

  private static async loadAllowedSession(context: common.Context, serverInstanceId: string): Promise<ServerAuthSession> {
    const policy = await HaConnectionPolicyService.resolveServerBaseUrl(context, serverInstanceId);
    if (!policy.allowed || policy.baseUrl.length === 0) {
      return {
        serverInstanceId: '',
        baseUrl: '',
        accessToken: '',
        refreshToken: ''
      };
    }
    const session = await ServerAuthRepository.loadFreshWithBaseUrl(context, serverInstanceId, policy.baseUrl);
    if (session.accessToken.length > 0) {
      session.baseUrl = policy.baseUrl;
    }
    return session;
  }

  private static async recordsByServer(context: common.Context, serverInstanceId: string): Promise<CardBindingRecord[]> {
    const light = await CardDataStore.listBindingsByType(context, CardType.LIGHT);
    const media = await CardDataStore.listBindingsByType(context, CardType.MEDIA);
    const scenes = await CardDataStore.listBindingsByType(context, CardType.SCENE);
    const cameras = await CardDataStore.listBindingsByType(context, CardType.CAMERA);
    return light.concat(media).concat(scenes).concat(cameras)
      .filter((record: CardBindingRecord): boolean => record.serverInstanceId === serverInstanceId.trim());
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

  private static optimisticMediaState(current: string, event: string): string {
    if (event === 'media_pause') {
      return 'paused';
    }
    if (event === 'media_play') {
      return 'playing';
    }
    if (event === 'media_play_pause') {
      return current === 'playing' ? 'paused' : 'playing';
    }
    if (event === 'media_stop') {
      return 'idle';
    }
    return current;
  }
}
