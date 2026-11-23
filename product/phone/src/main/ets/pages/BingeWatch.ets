/**
 * Copyright (c) 2023 Wathinst <wxz@xkzhineng.com>
 * OhBili is licensed under Mulan PSL v2.
 * You can use this software according to the terms and conditions of the Mulan PSL v2.
 * You may obtain a copy of Mulan PSL v2 at:
 * http://license.coscl.org.cn/MulanPSL2
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
 * EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
 * MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
 * See the Mulan PSL v2 for more details.
 */

import {
  ApiManager,
  ApiResponse,
  BangumiTimelineDay,
  BangumiTimelineEpisode,
  FollowBangumiItem,
  MyFollowBangumiData,
  MyFollowBangumiResponse,
  NavHelper
} from '@ohos/common';

/**
 * 番剧 Tab：顶部子页签「新番时间表」/「我的追番」
 * - 时间表：pgc/web/timeline 按天分组周历列表，今天高亮，点击进番剧详情
 * - 我的追番：需登录；x/space/bangumi/follow/list 网格卡片，上拉分页，点击进详情
 */

/** 时间表番剧类型：1=番剧 */
let TIMELINE_TYPES: number = 1;
/** 追番列表类型：1=追番 */
let FOLLOW_LIST_TYPE: number = 1;

@Component
export struct BingeWatchView {
  @State mCurrentTab: number = 0;
  // ---- 新番时间表 ----
  @State mDays: BangumiTimelineDay[] = [];
  @State mTimelineRefreshing: boolean = false;
  @State mTimelineLoaded: boolean = false;
  // ---- 我的追番 ----
  @StorageLink('isOhBiliLoggedIn') mLoggedIn: boolean = false;
  @State mFollowItems: FollowBangumiItem[] = [];
  @State mFollowTotal: number = 0;
  @State mFollowPn: number = 1;
  @State mFollowRefreshing: boolean = false;
  @State mFollowLoadingMore: boolean = false;
  @State mFollowLoaded: boolean = false;

  aboutToAppear() {
    this.loadTimeline();
  }

  private switchTab(index: number): void {
    this.mCurrentTab = index;
    if (index == 1 && this.mLoggedIn && !this.mFollowLoaded) {
      this.refreshFollow();
    }
  }

  // ---------- 新番时间表 ----------

  private loadTimeline(): void {
    ApiManager.getInstance().requestBangumiTimeline(TIMELINE_TYPES).then((days: BangumiTimelineDay[] | null) => {
      this.mTimelineRefreshing = false;
      this.mTimelineLoaded = true;
      if (days != null) {
        this.mDays = days;
      }
    }).catch(() => {
      this.mTimelineRefreshing = false;
      this.mTimelineLoaded = true;
    });
  }

  /** 更新时间（HH:mm） */
  private formatPubTime(ts: number): string {
    if (ts == null || ts <= 0) {
      return '';
    }
    let d: Date = new Date(ts * 1000);
    let h: number = d.getHours();
    let m: number = d.getMinutes();
    let hh: string = h < 10 ? '0' + h : '' + h;
    let mm: string = m < 10 ? '0' + m : '' + m;
    return hh + ':' + mm;
  }

  // ---------- 我的追番 ----------

  private refreshFollow(): void {
    this.mFollowPn = 1;
    this.loadFollow();
  }

  private loadFollow(): void {
    let midStr: string = AppStorage.get<string>('ohBiliDedeUserId') ?? '';
    let mid: number = parseInt(midStr);
    if (isNaN(mid) || mid <= 0) {
      this.mFollowRefreshing = false;
      this.mFollowLoadingMore = false;
      return;
    }
    ApiManager.getInstance().requestMyFollowBangumi(mid, FOLLOW_LIST_TYPE, this.mFollowPn)
      .then((resp: ApiResponse<MyFollowBangumiResponse>) => {
        this.mFollowRefreshing = false;
        this.mFollowLoadingMore = false;
        this.mFollowLoaded = true;
        if (resp.code == -1 || resp.result == null || resp.result.code != 0
          || resp.result.data == null) {
          return;
        }
        let data: MyFollowBangumiData = resp.result.data;
        this.mFollowTotal = data.total ?? 0;
        let list: FollowBangumiItem[] = data.list ?? [];
        if (this.mFollowPn <= 1) {
          this.mFollowItems = list;
        } else {
          this.mFollowItems = this.mFollowItems.concat(list);
        }
      }).catch(() => {
        this.mFollowRefreshing = false;
        this.mFollowLoadingMore = false;
        this.mFollowLoaded = true;
      });
  }

  private loadFollowMore(): void {
    if (this.mFollowLoadingMore || !this.mLoggedIn) {
      return;
    }
    if (this.mFollowTotal > 0 && this.mFollowItems.length >= this.mFollowTotal) {
      return;
    }
    this.mFollowLoadingMore = true;
    this.mFollowPn++;
    this.loadFollow();
  }

  // ---------- 布局 ----------

  @Builder
  tabBarText(title: string, index: number) {
    Text(title)
      .fontSize(16)
      .fontWeight(this.mCurrentTab === index ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.mCurrentTab === index ? '#1698CE' : $r('app.color.text_secondary'))
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .border({ width: { bottom: this.mCurrentTab === index ? 2 : 0 }, color: '#1698CE' })
      .onClick(() => {
        this.switchTab(index);
      })
  }

  @Builder
  timelinePane() {
    if (this.mDays.length == 0) {
      Column() {
        if (this.mTimelineLoaded) {
          Text('暂无新番时间表数据')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        } else {
          LoadingProgress().width(36).height(36)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: $$this.mTimelineRefreshing }) {
        List() {
          ForEach(this.mDays, (day: BangumiTimelineDay) => {
            ListItem() {
              Row() {
                Text(day.date ?? '')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                Text(' 周' + '日一二三四五六'.charAt(day.day_of_week ?? 0))
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                if (day.is_today) {
                  Text('今天')
                    .fontSize(10)
                    .fontColor(Color.White)
                    .backgroundColor('#fb7299')
                    .borderRadius(8)
                    .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                    .margin({ left: 8 })
                }
                Blank()
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 6 })
              .backgroundColor($r('app.color.surface'))
            }
            ForEach(day.episodes ?? [], (ep: BangumiTimelineEpisode) => {
              ListItem() {
                Row() {
                  Image(ep.cover ? ep.cover : $r('app.media.bg_default_show'))
                    .width(128)
                    .aspectRatio(1.6)
                    .borderRadius(4)
                    .objectFit(ImageFit.Cover)
                  Column() {
                    Text(ep.title ?? '')
                      .fontSize(14)
                      .fontColor($r('app.color.text_primary'))
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Blank()
                    Text((ep.index ?? '') + ' ' + (ep.index_title ?? ''))
                      .fontSize(12)
                      .fontColor($r('app.color.text_secondary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(this.formatPubTime(ep.pub_ts ?? 0) + ' 更新' + (ep.delay ? '（延期）' : ''))
                      .fontSize(11)
                      .fontColor($r('app.color.text_faint'))
                      .margin({ top: 2 })
                  }
                  .layoutWeight(1)
                  .height(80)
                  .alignItems(HorizontalAlign.Start)
                  .margin({ left: 10 })
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
                .padding({ left: 16, right: 16, top: 6, bottom: 6 })
                .onClick(() => {
                  NavHelper.goBangumi(ep.season_id ?? 0, ep.episode_id ?? 0);
                })
              }
            }, (ep: BangumiTimelineEpisode) => 'e' + ep.episode_id)
          }, (day: BangumiTimelineDay) => 'd' + day.date_ts)
        }
        .width('100%')
        .divider({ strokeWidth: 0.5, color: $r('app.color.divider'), startMargin: 16, endMargin: 16 })
        .edgeEffect(EdgeEffect.None)
      }
      .onRefreshing(() => {
        this.loadTimeline();
      })
      .layoutWeight(1)
    }
  }

  @Builder
  followPane() {
    if (!this.mLoggedIn) {
      Column() {
        Text('登录后可查看我的追番')
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
        Button('去登录')
          .margin({ top: 16 })
          .onClick(() => {
            NavHelper.goLogin();
          })
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else if (this.mFollowItems.length == 0) {
      Column() {
        if (this.mFollowLoaded) {
          Text('还没有追番，去时间表看看吧')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        } else {
          LoadingProgress().width(36).height(36)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: $$this.mFollowRefreshing }) {
        Grid() {
          ForEach(this.mFollowItems, (item: FollowBangumiItem) => {
            GridItem() {
              Column() {
                Stack({ alignContent: Alignment.BottomStart }) {
                  Image(item.cover ? item.cover : $r('app.media.bg_default_show'))
                    .width('100%')
                    .aspectRatio(0.72)
                    .borderRadius(6)
                    .objectFit(ImageFit.Cover)
                  Text(item.new_ep?.index_show ?? '')
                    .fontSize(10)
                    .fontColor(Color.White)
                    .backgroundColor('#99000000')
                    .borderRadius(4)
                    .maxLines(1)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .margin(4)
                }
                .width('100%')

                Text(item.title ?? '')
                  .fontSize(13)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 6 })
                Text(item.progress ?? '尚未观看')
                  .fontSize(11)
                  .fontColor($r('app.color.text_faint'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .onClick(() => {
                NavHelper.goBangumi(item.season_id ?? 0, 0);
              })
            }
          }, (item: FollowBangumiItem) => 'f' + item.season_id + '_' + this.mFollowItems.indexOf(item))
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .edgeEffect(EdgeEffect.None)
        .onReachEnd(() => {
          this.loadFollowMore();
        })
      }
      .onRefreshing(() => {
        this.refreshFollow();
      })
      .layoutWeight(1)
    }
  }

  build() {
    Column() {
      Row() {
        this.tabBarText('新番时间表', 0)
        this.tabBarText('我的追番', 1)
      }
      .width('100%')
      .padding({ left: 4 })
      .border({ width: { bottom: 0.5 }, color: $r('app.color.border') })

      if (this.mCurrentTab == 0) {
        this.timelinePane()
      } else {
        this.followPane()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface'))
  }
}
