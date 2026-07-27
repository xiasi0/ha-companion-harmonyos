import {
  HaAreaRegistryItem,
  HaDeviceRegistryItem,
  HaEntityCatalogItem,
  HaEntityRegistryItem,
  HaLightEntity,
  HaMediaPlayerEntity,
  HaRegistryCatalog
} from './HaApiModels';

class HaLightEntityPayload implements HaLightEntity {
  entityId: string = '';
  name: string = '';
  areaName: string = '';
  state: string = 'unknown';
}

class HaMediaPlayerEntityPayload implements HaMediaPlayerEntity {
  entityId: string = '';
  name: string = '';
  areaName: string = '';
  state: string = 'unknown';
  mediaTitle: string = '';
  mediaArtist: string = '';
  appName: string = '';
  entityPicture: string = '';
}

class HaEntityCatalogItemPayload implements HaEntityCatalogItem {
  entityId: string = '';
  domain: string = '';
  name: string = '';
  areaId: string = '';
  areaName: string = '';
  deviceId: string = '';
  deviceName: string = '';
  entityCategory: string = '';
  deviceClass: string = '';
  unitOfMeasurement: string = '';
  icon: string = '';
  state: string = 'unknown';
}

class HaAreaRegistryItemPayload implements HaAreaRegistryItem {
  areaId: string = '';
  name: string = '';
}

class HaDeviceRegistryItemPayload implements HaDeviceRegistryItem {
  deviceId: string = '';
  areaId: string = '';
  name: string = '';
}

class HaEntityRegistryItemPayload implements HaEntityRegistryItem {
  entityId: string = '';
  areaId: string = '';
  deviceId: string = '';
  entityCategory: string = '';
}

export class HaEntityParser {
  static parseEntityCatalog(body: string): HaEntityCatalogItem[] {
    const parsed = JSON.parse(body) as Array<Record<string, Object | string | number | boolean | null>>;
    const entities: HaEntityCatalogItem[] = [];
    for (let i = 0; i < parsed.length; i++) {
      const item = parsed[i];
      const rawEntityId = item['entity_id'];
      if (typeof rawEntityId !== 'string' || rawEntityId.indexOf('.') <= 0) {
        continue;
      }
      const attributes = HaEntityParser.objectField(item, 'attributes');
      const entity = new HaEntityCatalogItemPayload();
      entity.entityId = rawEntityId;
      entity.domain = rawEntityId.split('.')[0];
      entity.name = HaEntityParser.friendlyName(item);
      entity.deviceClass = attributes ? HaEntityParser.stringAttribute(attributes, 'device_class') : '';
      entity.unitOfMeasurement = attributes ? HaEntityParser.stringAttribute(attributes, 'unit_of_measurement') : '';
      entity.icon = attributes ? HaEntityParser.stringAttribute(attributes, 'icon') : '';
      entity.state = HaEntityParser.normalizedState(item['state']);
      entities.push(entity);
    }
    entities.sort((left: HaEntityCatalogItem, right: HaEntityCatalogItem): number => left.domain === right.domain
      ? left.name.localeCompare(right.name)
      : left.domain.localeCompare(right.domain));
    return entities;
  }

  static parseAreaRegistry(value: Object | string | number | boolean | null): HaAreaRegistryItem[] {
    if (!Array.isArray(value)) {
      return [];
    }
    const areas: HaAreaRegistryItem[] = [];
    for (let i = 0; i < value.length; i++) {
      const item = HaEntityParser.recordValue(value[i]);
      if (!item) {
        continue;
      }
      const area = new HaAreaRegistryItemPayload();
      area.areaId = HaEntityParser.stringAttribute(item, 'area_id');
      area.name = HaEntityParser.stringAttribute(item, 'name');
      if (area.areaId.length > 0) {
        areas.push(area);
      }
    }
    return areas;
  }

  static parseDeviceRegistry(value: Object | string | number | boolean | null): HaDeviceRegistryItem[] {
    if (!Array.isArray(value)) {
      return [];
    }
    const devices: HaDeviceRegistryItem[] = [];
    for (let i = 0; i < value.length; i++) {
      const item = HaEntityParser.recordValue(value[i]);
      if (!item) {
        continue;
      }
      const device = new HaDeviceRegistryItemPayload();
      device.deviceId = HaEntityParser.stringAttribute(item, 'id');
      device.areaId = HaEntityParser.stringAttribute(item, 'area_id');
      device.name = HaEntityParser.stringAttribute(item, 'name_by_user');
      if (device.name.length === 0) {
        device.name = HaEntityParser.stringAttribute(item, 'name');
      }
      if (device.deviceId.length > 0) {
        devices.push(device);
      }
    }
    return devices;
  }

  static parseEntityRegistry(value: Object | string | number | boolean | null): HaEntityRegistryItem[] {
    if (!Array.isArray(value)) {
      return [];
    }
    const entities: HaEntityRegistryItem[] = [];
    for (let i = 0; i < value.length; i++) {
      const item = HaEntityParser.recordValue(value[i]);
      if (!item) {
        continue;
      }
      const entity = new HaEntityRegistryItemPayload();
      entity.entityId = HaEntityParser.stringAttribute(item, 'entity_id');
      entity.areaId = HaEntityParser.stringAttribute(item, 'area_id');
      entity.deviceId = HaEntityParser.stringAttribute(item, 'device_id');
      entity.entityCategory = HaEntityParser.stringAttribute(item, 'entity_category');
      if (entity.entityId.length > 0) {
        entities.push(entity);
      }
    }
    return entities;
  }

  static mergeEntityCatalog(states: HaEntityCatalogItem[], registry: HaRegistryCatalog): HaEntityCatalogItem[] {
    const areas: Record<string, string> = {};
    const devices: Record<string, HaDeviceRegistryItem> = {};
    const entities: Record<string, HaEntityRegistryItem> = {};
    for (let i = 0; i < registry.areas.length; i++) {
      areas[registry.areas[i].areaId] = registry.areas[i].name;
    }
    for (let i = 0; i < registry.devices.length; i++) {
      devices[registry.devices[i].deviceId] = registry.devices[i];
    }
    for (let i = 0; i < registry.entities.length; i++) {
      entities[registry.entities[i].entityId] = registry.entities[i];
    }
    for (let i = 0; i < states.length; i++) {
      const meta = entities[states[i].entityId];
      const device = meta && meta.deviceId.length > 0 ? devices[meta.deviceId] : undefined;
      const areaId = meta && meta.areaId.length > 0 ? meta.areaId : (device ? device.areaId : '');
      states[i].areaId = areaId;
      states[i].areaName = areaId.length > 0 ? (areas[areaId] || areaId) : '';
      states[i].deviceId = meta ? meta.deviceId : '';
      states[i].deviceName = device ? device.name : '';
      states[i].entityCategory = meta ? meta.entityCategory : '';
    }
    return states;
  }

  static parseLightEntities(body: string): HaLightEntity[] {
    const parsed = JSON.parse(body) as Array<Record<string, Object | string | number | boolean | null>>;
    const lights: HaLightEntity[] = [];
    for (let i = 0; i < parsed.length; i++) {
      const item = parsed[i];
      const rawEntityId = item['entity_id'];
      if (typeof rawEntityId !== 'string' || !rawEntityId.startsWith('light.')) {
        continue;
      }
      const light = new HaLightEntityPayload();
      light.entityId = rawEntityId;
      light.state = HaEntityParser.normalizedLightState(item['state']);
      light.name = HaEntityParser.friendlyName(item);
      light.areaName = HaEntityParser.areaName(item);
      lights.push(light);
    }
    lights.sort((left: HaLightEntity, right: HaLightEntity): number => left.name.localeCompare(right.name));
    return lights;
  }

  static parseMediaPlayerEntities(body: string): HaMediaPlayerEntity[] {
    const parsed = JSON.parse(body) as Array<Record<string, Object | string | number | boolean | null>>;
    const players: HaMediaPlayerEntity[] = [];
    for (let i = 0; i < parsed.length; i++) {
      const item = parsed[i];
      const rawEntityId = item['entity_id'];
      if (typeof rawEntityId !== 'string' || !rawEntityId.startsWith('media_player.')) {
        continue;
      }
      players.push(HaEntityParser.parseMediaPlayerStateRecord(item));
    }
    players.sort((left: HaMediaPlayerEntity, right: HaMediaPlayerEntity): number => left.name.localeCompare(right.name));
    return players;
  }

  static parseLightState(body: string): string {
    const parsed = JSON.parse(body) as Record<string, Object | string | number | boolean | null>;
    return HaEntityParser.normalizedLightState(parsed['state']);
  }

  static parseMediaPlayerState(body: string): HaMediaPlayerEntity {
    const parsed = JSON.parse(body) as Record<string, Object | string | number | boolean | null>;
    return HaEntityParser.parseMediaPlayerStateRecord(parsed);
  }

  static parseMediaPlayerStateObject(
    item: Record<string, Object | string | number | boolean | null>
  ): HaMediaPlayerEntity {
    return HaEntityParser.parseMediaPlayerStateRecord(item);
  }

  static mediaPlayerService(action: string): string {
    if (action === 'media_play_pause') {
      return 'media_play_pause';
    }
    if (action === 'media_next') {
      return 'media_next_track';
    }
    if (action === 'media_previous') {
      return 'media_previous_track';
    }
    if (action === 'media_volume_down') {
      return 'volume_down';
    }
    if (action === 'media_volume_up') {
      return 'volume_up';
    }
    return '';
  }

  private static parseMediaPlayerStateRecord(
    item: Record<string, Object | string | number | boolean | null>
  ): HaMediaPlayerEntity {
    const player = new HaMediaPlayerEntityPayload();
    const rawEntityId = item['entity_id'];
    player.entityId = typeof rawEntityId === 'string' ? rawEntityId : '';
    player.state = HaEntityParser.normalizedState(item['state']);
    player.name = HaEntityParser.friendlyName(item);
    player.areaName = HaEntityParser.areaName(item);
    const attributes = HaEntityParser.objectField(item, 'attributes');
    if (attributes) {
      player.mediaTitle = HaEntityParser.stringAttribute(attributes, 'media_title');
      player.mediaArtist = HaEntityParser.stringAttribute(attributes, 'media_artist');
      player.appName = HaEntityParser.stringAttribute(attributes, 'app_name');
      player.entityPicture = HaEntityParser.stringAttribute(attributes, 'entity_picture');
    }
    return player;
  }

  private static normalizedLightState(value: Object | string | number | boolean | null): string {
    if (typeof value === 'string' && (value === 'on' || value === 'off')) {
      return value;
    }
    return 'unknown';
  }

  private static normalizedState(value: Object | string | number | boolean | null): string {
    if (typeof value === 'string' && value.trim().length > 0) {
      return value.trim();
    }
    return 'unknown';
  }

  private static friendlyName(item: Record<string, Object | string | number | boolean | null>): string {
    const attributes = HaEntityParser.objectField(item, 'attributes');
    if (attributes) {
      const rawName = attributes['friendly_name'];
      if (typeof rawName === 'string' && rawName.trim().length > 0) {
        return rawName.trim();
      }
    }
    const rawEntityId = item['entity_id'];
    return typeof rawEntityId === 'string' ? rawEntityId : 'Entity';
  }

  private static areaName(item: Record<string, Object | string | number | boolean | null>): string {
    const attributes = HaEntityParser.objectField(item, 'attributes');
    if (!attributes) {
      return '';
    }
    const rawArea = attributes['area_id'];
    return typeof rawArea === 'string' ? rawArea : '';
  }

  private static stringAttribute(source: Record<string, Object | string | number | boolean | null>, key: string): string {
    const value = source[key];
    return typeof value === 'string' ? value.trim() : '';
  }

  private static recordValue(value: Object | string | number | boolean | null): Record<string, Object | string | number | boolean | null> | null {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      return value as Record<string, Object | string | number | boolean | null>;
    }
    return null;
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
}
