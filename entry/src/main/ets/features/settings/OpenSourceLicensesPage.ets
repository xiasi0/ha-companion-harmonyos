import { HaTheme } from '../../shared/theme/HaTheme';
import { Localization } from '../../shared/i18n/Localization';
import { SettingsBoundary } from './components/SettingsBoundary';
import { SettingsStatusChip } from './components/SettingsStatusChip';
import { SettingsUiConfig } from './components/SettingsUiConfig';
import {
  HdsNavigation,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit';

interface OpenSourceLicenseItem {
  name: string;
  version: string;
  license: string;
  description: string;
}

@Component
export struct OpenSourceLicensesPage {
  @Prop contentMaxWidth: number = SettingsUiConfig.contentMaxWidth;
  @StorageLink('appResolvedDark') appResolvedDark: boolean = false;
  private scroller: Scroller = new Scroller();
  onBack: () => void = () => {};
  onSwipeBack: () => void = () => {};

  private items(): OpenSourceLicenseItem[] {
    return [
      {
        name: 'Home Assistant icon assets',
        version: 'current',
        license: 'Apache-2.0',
        description: Localization.t('license_ha_icon_assets')
      },
      {
        name: 'Google Material Symbols Rounded',
        version: 'subset',
        license: 'Apache-2.0',
        description: Localization.t('license_google_material_symbols')
      },
      {
        name: 'HarmonyOS SDK',
        version: '6.x',
        license: 'SDK',
        description: Localization.t('license_harmony_sdk')
      }
    ];
  }

  @Builder
  private renderChip(text: string, primary: boolean): void {
    SettingsStatusChip({ text: text, tone: primary ? 'accent' : 'neutral' })
  }

  @Builder
  private renderItem(item: OpenSourceLicenseItem): void {
    Column({ space: 8 }) {
      Text(item.name)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(HaTheme.textPrimary(this.appResolvedDark))
        .width('100%')

      Row({ space: 8 }) {
        if (item.version.length > 0) {
          this.renderChip(item.version, false)
        }
        this.renderChip(item.license, true)
      }
      .width('100%')

      Text(item.description)
        .fontSize(14)
        .fontColor(HaTheme.textSecondary(this.appResolvedDark))
        .lineHeight(20)
        .width('100%')
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 16, bottom: 16 })
    .backgroundColor(SettingsUiConfig.transparentBackground)
  }

  @Builder
  private renderPageContent(): void {
    List({ scroller: this.scroller, space: SettingsUiConfig.listSpace }) {
      ListItem() {
        Column() {
          ForEach(this.items(), (item: OpenSourceLicenseItem, index?: number) => {
            this.renderItem(item)
            if ((index ?? 0) < this.items().length - 1) {
              SettingsBoundary()
            }
          }, (item: OpenSourceLicenseItem) => item.name)
        }
        .width('100%')
        .borderRadius(SettingsUiConfig.groupRadius)
        .backgroundColor(HaTheme.surface(this.appResolvedDark))
        .shadow(SettingsUiConfig.groupShadow())
        .padding(SettingsUiConfig.groupPadding)
      }
      .width('100%')
    }
    .layoutWeight(1)
    .width('100%')
    .constraintSize({ maxWidth: this.contentMaxWidth })
    .padding(SettingsUiConfig.listPadding())
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .contentEndOffset(SettingsUiConfig.listContentEndOffset)
    .scrollBar(SettingsUiConfig.scrollBarState())
    .cachedCount(3, true)
    .clip(false)
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
    .alignListItem(ListItemAlign.Center)
  }

  build() {
    HdsNavigation() {
      this.renderPageContent()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(HaTheme.groupedBackground(this.appResolvedDark))
    .titleBar(SettingsUiConfig.titleBar(Localization.t('settings_open_source_licenses'), this.onBack, this.appResolvedDark))
    .bindToScrollable([this.scroller])
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 24 })
        .onActionEnd((event: GestureEvent) => {
          if (event.offsetX > 60 || event.offsetX < -60) {
            this.onSwipeBack();
          }
        })
    )
  }
}
