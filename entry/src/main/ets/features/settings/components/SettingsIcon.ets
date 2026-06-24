import { HaColors } from '../../../shared/constants/HaStyle';

@Component
export struct SettingsIcon {
  @Prop
  label: string = '';
  @Prop
  color: string = HaColors.SETTINGS_ACCENT;

  build() {
    Stack() {
      if (this.label === 'ha') {
        Image($r('app.media.ha_brand'))
          .width(24)
          .height(24)
          .objectFit(ImageFit.Contain)
      } else if (this.label === 'plus') {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'edit') {
        SymbolGlyph($r('sys.symbol.pencil_line_1'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'globe') {
        SymbolGlyph($r('sys.symbol.pencil_line_1'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'wifi') {
        SymbolGlyph($r('sys.symbol.wifi'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'computer') {
        SymbolGlyph($r('sys.symbol.house'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'lock') {
        SymbolGlyph($r('sys.symbol.lock_fill'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'remote') {
        SymbolGlyph($r('sys.symbol.key_horizontal'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'timeout') {
        SymbolGlyph($r('sys.symbol.stopwatch_2'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'websocket') {
        SymbolGlyph($r('sys.symbol.mobiledata'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'clear') {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'launch') {
        SymbolGlyph($r('sys.symbol.arrow_right_up_and_square'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'sensor') {
        SymbolGlyph($r('sys.symbol.dot_radiowaves_left_and_right'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'sensor_battery_level') {
        SymbolGlyph($r('sys.symbol.battery_75percent'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'sensor_battery_state') {
        SymbolGlyph($r('sys.symbol.battery'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'sensor_charger_type') {
        SymbolGlyph($r('sys.symbol.bolt'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'sensor_network_type') {
        SymbolGlyph($r('sys.symbol.hotspot'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'sensor_accurate_location') {
        SymbolGlyph($r('sys.symbol.position'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'sensor_zone_background') {
        SymbolGlyph($r('sys.symbol.map_badge_local'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'sensor_location_background') {
        SymbolGlyph($r('sys.symbol.local_fill'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'sensor_last_update_trigger') {
        SymbolGlyph($r('sys.symbol.timer'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'sensor_update') {
        SymbolGlyph($r('sys.symbol.clock'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'gestures') {
        SymbolGlyph($r('sys.symbol.hand_draw'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'fullscreen') {
        SymbolGlyph($r('sys.symbol.arrow_up_left_and_arrow_down_right'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'orientation') {
        SymbolGlyph($r('sys.symbol.rectangle_portrait_rotate'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'keep_screen') {
        SymbolGlyph($r('sys.symbol.sun_max'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'zoom') {
        SymbolGlyph($r('sys.symbol.plus_magnifyingglass'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'pinch_zoom') {
        SymbolGlyph($r('sys.symbol.hand_tap'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'autoplay_video') {
        SymbolGlyph($r('sys.symbol.play_video'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'show_first_view') {
        SymbolGlyph($r('sys.symbol.house'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'nfc') {
        SymbolGlyph($r('sys.symbol.nfc'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'card_update_frequency') {
        SymbolGlyph($r('sys.symbol.more'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'language') {
        SymbolGlyph($r('sys.symbol.translate'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'theme') {
        SymbolGlyph($r('sys.symbol.paintpalette'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'notifications') {
        SymbolGlyph($r('sys.symbol.bell_fill'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'assist') {
        SymbolGlyph($r('sys.symbol.ellipsis_message'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'headphones') {
        SymbolGlyph($r('sys.symbol.headphones_fill'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'license') {
        SymbolGlyph($r('sys.symbol.bookmark'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'privacy') {
        SymbolGlyph($r('sys.symbol.eye'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'lightbulb') {
        SymbolGlyph($r('sys.symbol.lightbulb'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'music') {
        SymbolGlyph($r('sys.symbol.play_fill'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'scene') {
        SymbolGlyph($r('sys.symbol.play_fill'))
          .fontSize(24)
          .fontColor([this.color])
      } else if (this.label === 'info') {
        SymbolGlyph($r('sys.symbol.info_circle'))
          .fontSize(24)
          .fontColor([this.color])
      } else {
        Text(this.label)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.color)
      }
    }
    .width(56)
    .height(56)
  }
}
