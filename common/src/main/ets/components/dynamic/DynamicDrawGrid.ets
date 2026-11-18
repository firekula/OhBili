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

import { MajorDrawItem, getDrawItemUrl, getDrawItemWidth,
  getDrawItemHeight } from '../../model/response/DynamicFeedResponse';
import { NavHelper } from '../../utils/NavHelper';
import { BLog } from '../../utils/BLog';

/**
 * 图文九宫格：1 图单图限高自适应（不强撑九宫格）、2/4 图两列、其余三列网格；
 * 点击任一图进入全屏预览。
 */
@Component
export struct DynamicDrawGrid {
  @Prop images: MajorDrawItem[];
  /** 按行分块后的图片二维数组（aboutToAppear 预计算） */
  private rows: MajorDrawItem[][] = [];

  aboutToAppear() {
    this.rows = this.buildRows();
    if (this.images != null && this.images.length > 0) {
      BLog.d("DynamicDrawGrid aboutToAppear images=" + this.images.length
        + ", firstUrl=" + getDrawItemUrl(this.images[0]));
    }
  }

  build() {
    if (this.images != null && this.images.length > 0) {
      Column({ space: 4 }) {
        ForEach(this.rows, (row: MajorDrawItem[], rowIndex: number) => {
          Row({ space: 4 }) {
            ForEach(row, (img: MajorDrawItem, colIndex: number) => {
              this.ImageCell(img, rowIndex * this.columnCount() + colIndex)
            }, img => getDrawItemUrl(img))
          }
          .width('100%')
        }, (row: MajorDrawItem[], rowIndex: number) => rowIndex.toString())
      }.width('100%')
    }
  }

  @Builder
  private ImageCell(img: MajorDrawItem, globalIndex: number) {
    if (this.isSingleImage()) {
      // 单图：限高自适应展示，不强撑九宫格
      Image(getDrawItemUrl(img))
        .width('65%')
        .aspectRatio(this.imageRatio(img))
        .constraintSize({ maxHeight: 240 })
        .objectFit(ImageFit.Contain)
        .borderRadius(4)
        .alt($r('app.media.bg_default_show'))
        .onClick(() => {
          NavHelper.goGallery(this.imageUrls(), globalIndex);
        })
    } else {
      // 多图：等宽网格单元
      Image(getDrawItemUrl(img))
        .layoutWeight(1)
        .aspectRatio(1)
        .objectFit(ImageFit.Cover)
        .borderRadius(4)
        .alt($r('app.media.bg_default_show'))
        .onClick(() => {
          NavHelper.goGallery(this.imageUrls(), globalIndex);
        })
    }
  }

  private isSingleImage(): boolean {
    return this.images != null && this.images.length == 1;
  }

  /**
   * 网格列数：1 图单列、2/4 图两列、其余三列（最多 9 图）
   */
  private columnCount(): number {
    let count: number = this.images == null ? 0 : this.images.length;
    if (count == 1) {
      return 1;
    }
    if (count == 2 || count == 4) {
      return 2;
    }
    return 3;
  }

  /**
   * 单图宽高比（缺省 1:1 兜底）
   */
  private imageRatio(img: MajorDrawItem): number {
    let width: number = getDrawItemWidth(img);
    let height: number = getDrawItemHeight(img);
    if (width > 0 && height > 0) {
      return width / height;
    }
    return 1;
  }

  /**
   * 按列数将图片分块为行
   */
  private buildRows(): MajorDrawItem[][] {
    let result: MajorDrawItem[][] = [];
    if (this.images == null || this.images.length == 0) {
      return result;
    }
    let columns: number = this.columnCount();
    let row: MajorDrawItem[] = [];
    for (let i = 0; i < this.images.length; i++) {
      row.push(this.images[i]);
      if (row.length >= columns) {
        result.push(row);
        row = [];
      }
    }
    if (row.length > 0) {
      result.push(row);
    }
    return result;
  }

  /**
   * 图片 URL 列表（供全屏预览）
   */
  private imageUrls(): string[] {
    let urls: string[] = [];
    if (this.images != null) {
      for (let i = 0; i < this.images.length; i++) {
        urls.push(getDrawItemUrl(this.images[i]));
      }
    }
    return urls;
  }
}
