// Keep dynamic row values as component props so updates also refresh off-screen rows.
@Component
export struct DemoAction {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop icon: string = '';
  @Prop color: string = '#4F46E5';
  @Prop disabled: boolean = false;
  identifier: string = '';
  onAction: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Text(this.icon).fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.color)
        .width(34).height(34).textAlign(TextAlign.Center).backgroundColor('#18' + this.color.slice(1)).borderRadius(9)
      Column({ space: 4 }) {
        Text(this.title).fontSize(15).fontColor('#202124').width('100%')
        Text(this.subtitle).fontSize(11).fontColor('#6B7280').width('100%').maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text('›').fontSize(22).fontColor('#B3B7C0')
    }.width('100%').padding(14).backgroundColor(Color.White).borderRadius(12).margin({ bottom: 2 })
      .enabled(!this.disabled).opacity(this.disabled ? 0.5 : 1).onClick(() => this.onAction()).id(this.identifier)
  }
}
@Component
export struct DemoToggle {
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop value: boolean = false;
  @Prop disabled: boolean = false;
  identifier: string = '';
  onToggle: (value: boolean) => void = () => {};

  build() {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(this.title).fontSize(15).fontColor('#202124')
        Text(this.subtitle).fontSize(11).fontColor('#6B7280')
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.value }).selectedColor('#4F46E5').enabled(!this.disabled)
        .onChange((value: boolean) => this.onToggle(value)).id(this.identifier)
    }.width('100%').padding(14).backgroundColor(Color.White).borderRadius(12).margin({ bottom: 2 })
  }
}
@Component
export struct DemoStat {
  @Prop value: string = '';
  @Prop label: string = '';
  build() {
    Column({ space: 6 }) {
      Text(this.value).fontSize(18).fontWeight(FontWeight.Bold).fontColor(Color.White)
      Text(this.label).fontSize(11).fontColor('#DEDCFF')
    }.layoutWeight(1)
  }
}
@Component
export struct DemoHeader {
  @Prop title: string = '';
  @Prop chinese: boolean = true;
  @Prop busy: boolean = false;
  onBack: () => void = () => {};
  onLanguage: () => void = () => {};
  build() {
    Row() {
      Button('‹').fontSize(28).fontColor('#4F46E5').backgroundColor(Color.Transparent).width(48)
        .onClick(() => this.onBack()).enabled(!this.busy).id('demo.back')
      Text(this.title).fontSize(19).fontWeight(FontWeight.Bold).layoutWeight(1).fontColor('#202124').maxLines(1)
      Button(this.chinese ? 'EN' : '中文').fontSize(13).fontColor('#4F46E5').backgroundColor(Color.Transparent)
        .onClick(() => this.onLanguage()).id('demo.language')
    }.width('100%').height(56).padding({ right: 8 }).backgroundColor('#F2F2F7')
  }
}
@Component
export struct DemoSection {
  @Prop label: string = '';
  build() {
    Text(this.label).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#6B7280')
      .width('100%').padding({ left: 8, top: 22, bottom: 10 })
  }
}
@Component
export struct DemoField {
  @Prop label: string = '';
  build() {
    Text(this.label).fontSize(13).fontColor('#6B7280').width('100%').margin({ top: 18, bottom: 8 })
  }
}
