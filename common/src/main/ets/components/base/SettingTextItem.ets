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

@Component
export struct SettingTextItem {
  private title: string;
  @Link value: string;
  private arr: string[] = [];
  private callback: () => void = () => {
    if (this.arr.length > 0) {
      TextPickerDialog.show({
        range: this.arr,
        selected: this.arr.indexOf(this.value),
        onAccept: (value: TextPickerResult) => {
          let index: number = -1;
          if (typeof value.index === 'number') {
            index = value.index;
          } else if (Array.isArray(value.index) && value.index.length > 0) {
            index = value.index[0];
          }
          if (index >= 0 && index < this.arr.length) {
            this.value = this.arr[index]
          }
        } })
    }
  }

  build() {
    Row() {
      Text(this.title).fontSize(14).fontColor('#333333')
      Blank()
      Text(this.value).fontSize(14).fontColor('#888888').onClick(this.callback)
    }.width('100%').height(50)
  }
}