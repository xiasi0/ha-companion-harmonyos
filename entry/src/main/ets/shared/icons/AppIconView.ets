import { AppIconSource, AppIconSpec, materialIcon } from './AppIconModels';
import { MaterialSymbolIcon } from './MaterialSymbolIcon';
import { MaterialSymbols } from './MaterialSymbols';

@Component
export struct AppIconView {
  @Prop
  icon: AppIconSpec = materialIcon('settings');
  @Prop
  iconSize: number = 24;
  @Prop
  slotSize: number = 56;
  @Prop
  color: ResourceColor = '#172126';
  @Prop
  replaceEffect: boolean = false;

  private materialCodepoint(): number {
    switch (this.icon.name) {
      case 'account_tree':
        return MaterialSymbols.account_tree;
      case 'arrow_downward':
        return MaterialSymbols.arrow_downward;
      case 'arrow_upward':
        return MaterialSymbols.arrow_upward;
      case 'battery_charging_80':
        return MaterialSymbols.battery_charging_80;
      case 'battery_charging_full':
        return MaterialSymbols.battery_charging_full;
      case 'battery_health':
        return MaterialSymbols.battery_health;
      case 'battery_plus':
        return MaterialSymbols.battery_plus;
      case 'bluetooth':
        return MaterialSymbols.bluetooth;
      case 'brightness_6':
        return MaterialSymbols.brightness_6;
      case 'bring_your_own_ip':
        return MaterialSymbols.bring_your_own_ip;
      case 'circle':
        return MaterialSymbols.circle;
      case 'distance':
        return MaterialSymbols.distance;
      case 'do_not_disturb_sensor':
        return MaterialSymbols.do_not_disturb_sensor;
      case 'hard_disk':
        return MaterialSymbols.hard_disk;
      case 'home':
        return MaterialSymbols.home;
      case 'headphones':
        return MaterialSymbols.headphones;
      case 'last_reboot_time':
        return MaterialSymbols.last_reboot_time;
      case 'last_update_trigger':
        return MaterialSymbols.last_update_trigger;
      case 'leak_add':
        return MaterialSymbols.leak_add;
      case 'lightbulb':
        return MaterialSymbols.lightbulb;
      case 'location_permission':
        return MaterialSymbols.location_permission;
      case 'map_search':
        return MaterialSymbols.map_search;
      case 'memory':
        return MaterialSymbols.memory;
      case 'mobile_data_roaming':
        return MaterialSymbols.mobile_data_roaming;
      case 'mobile_hand':
        return MaterialSymbols.mobile_hand;
      case 'mobile_lock_portrait':
        return MaterialSymbols.mobile_lock_portrait;
      case 'mobile_off':
        return MaterialSymbols.mobile_off;
      case 'mobile_speaker':
        return MaterialSymbols.mobile_speaker;
      case 'mobiledata_arrows':
        return MaterialSymbols.mobiledata_arrows;
      case 'mode_night':
        return MaterialSymbols.mode_night;
      case 'my_location':
        return MaterialSymbols.my_location;
      case 'network_wifi':
        return MaterialSymbols.network_wifi;
      case 'nfc':
        return MaterialSymbols.nfc;
      case 'notification_sound':
        return MaterialSymbols.notification_sound;
      case 'phone_enabled':
        return MaterialSymbols.phone_enabled;
      case 'phone_in_talk':
        return MaterialSymbols.phone_in_talk;
      case 'power':
        return MaterialSymbols.power;
      case 'search':
        return MaterialSymbols.search;
      case 'screen_rotation':
        return MaterialSymbols.screen_rotation;
      case 'security':
        return MaterialSymbols.security;
      case 'settings':
        return MaterialSymbols.settings;
      case 'sim_card':
        return MaterialSymbols.sim_card;
      case 'sunny':
        return MaterialSymbols.sunny;
      case 'touch_app':
        return MaterialSymbols.touch_app;
      case 'trackpad_input':
        return MaterialSymbols.trackpad_input;
      case 'update':
        return MaterialSymbols.update;
      case 'volume_up':
        return MaterialSymbols.volume_up;
      case 'wifi':
        return MaterialSymbols.wifi;
      case 'wifi_tethering':
        return MaterialSymbols.wifi_tethering;
      default:
        return 0;
    }
  }

  @Builder
  private renderMaterialIcon(): void {
    if (this.materialCodepoint() > 0) {
      MaterialSymbolIcon({
        codepoint: this.materialCodepoint(),
        iconSize: this.iconSize,
        color: this.color
      })
    } else {
      Blank()
    }
  }

  @Builder
  private renderSystemIcon(): void {
    if (this.icon.name === 'ha') {
      Image($r('app.media.ha_brand'))
        .width(this.iconSize)
        .height(this.iconSize)
        .objectFit(ImageFit.Contain)
    } else if (this.icon.name === 'plus') {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'minus') {
      SymbolGlyph($r('sys.symbol.minus'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'edit') {
      SymbolGlyph($r('sys.symbol.pencil_line_1'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'globe') {
      SymbolGlyph($r('sys.symbol.pencil_line_1'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'wifi') {
      SymbolGlyph($r('sys.symbol.wifi'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'computer') {
      SymbolGlyph($r('sys.symbol.house'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'lock') {
      SymbolGlyph($r('sys.symbol.lock_fill'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'remote') {
      SymbolGlyph($r('sys.symbol.key_horizontal'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'timeout') {
      SymbolGlyph($r('sys.symbol.stopwatch_2'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'websocket') {
      SymbolGlyph($r('sys.symbol.mobiledata'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'clear') {
      SymbolGlyph($r('sys.symbol.xmark'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'launch') {
      SymbolGlyph($r('sys.symbol.arrow_right_up_and_square'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'sensor') {
      SymbolGlyph($r('sys.symbol.dot_radiowaves_left_and_right'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'sensor_battery_level') {
      SymbolGlyph($r('sys.symbol.battery_75percent'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'sensor_battery_state') {
      SymbolGlyph($r('sys.symbol.battery'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'sensor_charger_type') {
      SymbolGlyph($r('sys.symbol.bolt'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'sensor_network_type') {
      SymbolGlyph($r('sys.symbol.hotspot'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'sensor_accurate_location') {
      SymbolGlyph($r('sys.symbol.position'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'sensor_zone_background') {
      SymbolGlyph($r('sys.symbol.map_badge_local'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'sensor_location_background') {
      SymbolGlyph($r('sys.symbol.local_fill'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'sensor_last_update_trigger') {
      SymbolGlyph($r('sys.symbol.timer'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'sensor_update') {
      SymbolGlyph($r('sys.symbol.clock'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'gestures') {
      SymbolGlyph($r('sys.symbol.hand_draw'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'fullscreen') {
      SymbolGlyph($r('sys.symbol.arrow_up_left_and_arrow_down_right'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'orientation') {
      SymbolGlyph($r('sys.symbol.rectangle_portrait_rotate'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'keep_screen') {
      SymbolGlyph($r('sys.symbol.sun_max'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'zoom') {
      SymbolGlyph($r('sys.symbol.plus_magnifyingglass'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'pinch_zoom') {
      SymbolGlyph($r('sys.symbol.hand_tap'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'autoplay_video') {
      SymbolGlyph($r('sys.symbol.play_video'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'show_first_view') {
      SymbolGlyph($r('sys.symbol.house'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'nfc') {
      SymbolGlyph($r('sys.symbol.nfc'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'card_update_frequency') {
      SymbolGlyph($r('sys.symbol.more'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'language') {
      SymbolGlyph($r('sys.symbol.translate'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'theme') {
      SymbolGlyph($r('sys.symbol.paintpalette'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'notifications') {
      SymbolGlyph($r('sys.symbol.bell_fill'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'assist') {
      SymbolGlyph($r('sys.symbol.ellipsis_message'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'headphones') {
      SymbolGlyph($r('sys.symbol.headphones_fill'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'license') {
      SymbolGlyph($r('sys.symbol.bookmark'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'privacy') {
      SymbolGlyph($r('sys.symbol.eye'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'lightbulb') {
      SymbolGlyph($r('sys.symbol.lightbulb'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'music') {
      SymbolGlyph($r('sys.symbol.play_fill'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'scene') {
      SymbolGlyph($r('sys.symbol.play_fill'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'info') {
      SymbolGlyph($r('sys.symbol.info_circle'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'chevron_right') {
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'chevron_down') {
      SymbolGlyph($r('sys.symbol.chevron_down'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'chevron_up') {
      SymbolGlyph($r('sys.symbol.chevron_up'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'mic') {
      SymbolGlyph($r('sys.symbol.mic_fill'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'keyboard') {
      SymbolGlyph($r('sys.symbol.keyboard_circle'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'send') {
      SymbolGlyph($r('sys.symbol.paperplane_right_fill'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'search') {
      SymbolGlyph($r('sys.symbol.magnifyingglass'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'question') {
      SymbolGlyph($r('sys.symbol.questionmark_circle'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'arrow_left') {
      SymbolGlyph($r('sys.symbol.arrow_left'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'refresh') {
      SymbolGlyph($r('sys.symbol.arrow_clockwise'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'drive') {
      SymbolGlyph($r('sys.symbol.externaldrive_fill_3'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'power') {
      SymbolGlyph($r('sys.symbol.power'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'speaker') {
      SymbolGlyph($r('sys.symbol.speaker_wave_3'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
    } else if (this.icon.name === 'pause') {
      SymbolGlyph($r('sys.symbol.pause'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
        .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), this.replaceEffect)
    } else if (this.icon.name === 'play') {
      SymbolGlyph($r('sys.symbol.play_fill'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
        .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), this.replaceEffect)
    } else if (this.icon.name === 'previous') {
      SymbolGlyph($r('sys.symbol.backward_end_fill'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
        .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), this.replaceEffect)
    } else if (this.icon.name === 'next') {
      SymbolGlyph($r('sys.symbol.forward_end_fill'))
        .fontSize(this.iconSize)
        .fontColor([this.color])
        .symbolEffect(new ReplaceSymbolEffect(EffectScope.WHOLE), this.replaceEffect)
    } else {
      Text(this.icon.name)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.color)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.icon.source === AppIconSource.SYSTEM) {
        this.renderSystemIcon()
      } else {
        this.renderMaterialIcon()
      }
    }
    .width(this.slotSize)
    .height(this.slotSize)
  }
}
