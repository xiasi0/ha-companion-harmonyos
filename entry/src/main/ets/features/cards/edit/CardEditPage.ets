import common from '@ohos.app.ability.common';
import { actionSettingsItem, detailSettingsItem, SettingsItem, SettingsSection } from '../../../models/SettingsItem';
import { HaConnectionPolicyService } from '../../../services/HaConnectionPolicyService';
import { ManagedServer, ServerManager } from '../../../services/ServerManager';
import { SystemEventService } from '../../../services/SystemEventService';
import { CardCatalogSyncService } from '../CardCatalogSyncService';
import { CardBindingRecord, CardDataStore, CardType, HaEntityCatalogRecord } from '../CardDataStore';
import { CardRuntimeRepository } from '../CardRuntimeRepository';
import { SettingsHomePage } from '../../settings/SettingsHomePage';
import { Localization } from '../../../shared/i18n/Localization';

@Entry
@Component
struct CardEditPage {
  @StorageLink('cardEditFormId') @Watch('onEditTargetChanged') formId: string = '';
  @StorageLink('cardEditCardType') @Watch('onEditTargetChanged') cardEditCardType: string = '';
  @State private serverInstanceId: string = '';
  @State private baseUrl: string = '';
  @State private cardType: string = CardType.LIGHT;
  @State private searchText: string = '';
  @State private sections: SettingsSection[] = [
    {
      title: '',
      items: [
        detailSettingsItem('info', '加载中', '正在读取可关联的实体', '', '')
      ]
    }
  ];
  @State private revision: number = 0;
  private readonly systemEventService: SystemEventService = new SystemEventService();
  private reloadTimer: number = 0;
  private entityRecords: HaEntityCatalogRecord[] = [];

  aboutToAppear(): void {
    this.loadEntities();
    this.systemEventService.subscribeNetworkEvents((): void => {
      this.scheduleReload();
    });
  }

  aboutToDisappear(): void {
    this.systemEventService.unsubscribeAll();
    if (this.reloadTimer > 0) {
      clearTimeout(this.reloadTimer);
      this.reloadTimer = 0;
    }
  }

  private onEditTargetChanged(): void {
    this.searchText = '';
    this.entityRecords = [];
    this.sections = [
      {
        title: '',
        items: [
          detailSettingsItem('info', '加载中', '正在读取可关联的实体', '', '')
        ]
      }
    ];
    this.revision++;
    this.scheduleReload();
  }

  private scheduleReload(): void {
    if (this.reloadTimer > 0) {
      clearTimeout(this.reloadTimer);
    }
    this.reloadTimer = setTimeout((): void => {
      this.reloadTimer = 0;
      this.loadEntities();
    }, 500);
  }

  private loadEntities(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    ServerManager.getActiveServer(context)
      .then(async (server: ManagedServer | undefined): Promise<void> => {
        if (!server) {
          this.serverInstanceId = '';
          this.baseUrl = '';
          this.entityRecords = [];
          this.sections = this.messageSections('未连接 Home Assistant', '请先在应用中完成服务器登录。');
          this.revision++;
          return;
        }

        const binding = await CardDataStore.loadBinding(context, this.formId);
        this.cardType = this.resolveCardType(binding);
        this.serverInstanceId = server.id;
        const policy = await HaConnectionPolicyService.resolveServerBaseUrl(context, server.id);
        if (!policy.allowed || policy.baseUrl.length === 0) {
          this.baseUrl = '';
          this.entityRecords = [];
          this.sections = this.messageSections(Localization.t('block_insecure_title'), Localization.t('block_insecure_content'));
          this.revision++;
          return;
        }

        this.baseUrl = policy.baseUrl;
        await CardCatalogSyncService.forceSyncServer(context, server.id).catch((): boolean => false);
        this.entityRecords = await CardDataStore.listEntityCatalog(context, server.id, this.domainForCurrentCard());
        this.sections = this.entitySections();
        this.revision++;
      })
      .catch((): void => {
        this.entityRecords = [];
        this.sections = this.messageSections('加载失败', '暂时无法读取可关联的实体。');
        this.revision++;
      });
  }

  private resolveCardType(binding: CardBindingRecord): string {
    if (binding.cardType === CardType.MEDIA) {
      return CardType.MEDIA;
    }
    if (binding.cardType === CardType.LIGHT) {
      return CardType.LIGHT;
    }
    if (binding.cardType === CardType.SCENE) {
      return CardType.SCENE;
    }
    if (this.cardEditCardType === CardType.MEDIA) {
      return CardType.MEDIA;
    }
    if (this.cardEditCardType === CardType.SCENE) {
      return CardType.SCENE;
    }
    return CardType.LIGHT;
  }

  private domainForCurrentCard(): string {
    if (this.cardType === CardType.MEDIA) {
      return 'media_player';
    }
    if (this.cardType === CardType.SCENE) {
      return 'scene';
    }
    return 'light';
  }

  private iconForCurrentCard(): string {
    if (this.cardType === CardType.MEDIA) {
      return 'music';
    }
    if (this.cardType === CardType.SCENE) {
      return 'scene';
    }
    return 'lightbulb';
  }

  private entitySections(): SettingsSection[] {
    if (this.formId.trim().length === 0) {
      return this.messageSections('缺少卡片 ID', '请从桌面服务卡片进入编辑。');
    }
    if (this.entityRecords.length === 0) {
      return this.messageSections('没有可关联实体', '请确认 Home Assistant 中已有可关联实体。');
    }

    const entities = this.filteredEntities();
    if (entities.length === 0) {
      return this.messageSections('未找到相关实体', '请检查名称和 Home Assistant 服务器。');
    }

    return [
      {
        title: '可关联实体',
        items: entities.map((entity: HaEntityCatalogRecord): SettingsItem => {
          return actionSettingsItem(
            this.iconForCurrentCard(),
            entity.entityName.length > 0 ? entity.entityName : entity.entityId,
            this.entitySummary(entity),
            '',
            `bind:${entity.entityId}`
          );
        })
      }
    ];
  }

  private filteredEntities(): HaEntityCatalogRecord[] {
    const query = this.searchText.trim().toLowerCase();
    if (query.length === 0) {
      return this.entityRecords;
    }
    return this.entityRecords.filter((entity: HaEntityCatalogRecord): boolean => {
      return entity.entityId.toLowerCase().includes(query) ||
        entity.entityName.toLowerCase().includes(query) ||
        entity.areaName.toLowerCase().includes(query);
    });
  }

  private entitySummary(entity: HaEntityCatalogRecord): string {
    return `${this.stateText(entity.state)} | ${this.areaText(entity.areaName)}`;
  }

  private stateText(state: string): string {
    if (this.cardType === CardType.MEDIA) {
      if (state === 'playing') {
        return Localization.t('state_playing');
      }
      if (state === 'paused') {
        return Localization.t('state_paused');
      }
      if (state === 'idle') {
        return Localization.t('state_idle');
      }
    } else if (this.cardType === CardType.LIGHT) {
      if (state === 'on') {
        return Localization.t('state_on');
      }
      if (state === 'off') {
        return Localization.t('state_off');
      }
    }
    return Localization.t('state_unknown');
  }

  private areaText(areaName: string): string {
    const value = areaName.trim();
    return value.length > 0 ? value : Localization.t('state_unknown');
  }

  private messageSections(title: string, summary: string): SettingsSection[] {
    return [
      {
        title: '',
        items: [
          detailSettingsItem('info', title, summary, '', '')
        ]
      }
    ];
  }

  private handleAction(actionId: string): void {
    if (!actionId.startsWith('bind:')) {
      return;
    }
    const entityId = actionId.substring('bind:'.length);
    const target = this.entityRecords.find((entity: HaEntityCatalogRecord): boolean => entity.entityId === entityId);
    if (!target || this.formId.trim().length === 0 || this.serverInstanceId.trim().length === 0) {
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    HaConnectionPolicyService.resolveServerBaseUrl(context, this.serverInstanceId)
      .then((policy) => {
        if (!policy.allowed || policy.baseUrl.length === 0) {
          this.baseUrl = '';
          this.entityRecords = [];
          this.sections = this.messageSections(Localization.t('block_insecure_title'), Localization.t('block_insecure_content'));
          this.revision++;
          return Promise.reject(new Error('blocked_by_connection_policy'));
        }
        this.baseUrl = policy.baseUrl;
        if (this.cardType === CardType.MEDIA) {
          return CardRuntimeRepository.bindMediaCatalogEntity(context, this.formId, this.serverInstanceId, policy.baseUrl, target);
        }
        if (this.cardType === CardType.SCENE) {
          return CardRuntimeRepository.bindSceneEntity(
            context,
            this.formId,
            this.serverInstanceId,
            target.entityId,
            target.entityName.length > 0 ? target.entityName : target.entityId,
            target.areaId,
            target.areaName,
            target.state
          );
        }
        return CardRuntimeRepository.bindLightEntity(
            context,
            this.formId,
            this.serverInstanceId,
            target.entityId,
            target.entityName.length > 0 ? target.entityName : target.entityId,
            target.areaId,
            target.areaName,
            target.state
          );
      })
      .then((): void => this.close())
      .catch((): void => {
        if (this.entityRecords.length === 0 && this.baseUrl.length === 0) {
          return;
        }
        this.sections = this.messageSections('关联失败', '请稍后重试。');
        this.revision++;
      });
  }

  private close(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.terminateSelf().catch((): void => {});
  }

  build() {
    Column() {
      SettingsHomePage({
        title: '关联设备或实体',
        hideBackButton: false,
        sections: this.sections,
        showSearch: true,
        searchText: this.searchText,
        searchPlaceholder: '搜索实体',
        onBack: (): void => this.close(),
        onSwipeBack: (): void => this.close(),
        onSearchChange: (value: string): void => {
          this.searchText = value;
          this.sections = this.entitySections();
          this.revision++;
        },
        onAction: (actionId: string): void => this.handleAction(actionId)
      })
    }
    .width('100%')
    .height('100%')
  }
}
