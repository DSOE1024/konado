import { defineConfig } from 'vitepress'
import { MermaidMarkdown, MermaidPlugin } from 'vitepress-plugin-mermaid';

export default defineConfig({

  lastUpdated: true,

  markdown: {
    config(md) {
      md.use(MermaidMarkdown);
    },
  },
  vite: {
    plugins: [MermaidPlugin()],
    optimizeDeps: {
      include: ['mermaid'],
    },
    ssr: {
      noExternal: ['mermaid'],
    },
  },

  title: "Konado",
  base: "/konado/",
  description: "Konado: Visual Novel Framework",
  head: [
    [
      'link',
      { rel: 'icon', href: 'https://godothub.atomgit.net/web/icon/konado/kona/icon.png' }
    ]
  ],
  themeConfig: {
    outline: [2, 3],
    logo: 'https://godothub.atomgit.net/web/icon/konado/kona/icon.png',
    search: {
      provider: 'local'
    },
    socialLinks: [
      {
        icon: 'github', link: 'https://github.com/godothub/konado'
      },
      {
        icon:
        {
          svg: '<svg t="1752549910319" class="icon" viewBox="0 0 1024 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="4388" width="200" height="200"><path d="M512 512m-512 0a512 512 0 1 0 1024 0 512 512 0 1 0-1024 0Z" fill="#FFAD16" p-id="4389"></path><path d="M500.053333 571.733333s-8.533333-25.6-8.533333-35.84v-5.12c0-58.026667 46.08-105.813333 100.693333-105.813333 27.306667 0 52.906667 5.12 71.68 25.6 13.653333-15.36 32.426667-22.186667 52.906667-23.893333-5.12-81.92-69.973333-153.6-150.186667-153.6-40.96 0-80.213333 17.066667-107.52 47.786666C431.786667 290.133333 392.533333 273.066667 351.573333 273.066667c-83.626667 0-150.186667 69.973333-150.186666 155.306666v8.533334c0 15.36 3.413333 32.426667 10.24 49.493333v1.706667c46.08 109.226667 221.866667 237.226667 230.4 242.346666 5.12 3.413333 10.24 5.12 15.36 5.12 5.12 0 11.946667-1.706667 15.36-5.12 3.413333-3.413333 39.253333-27.306667 88.746666-69.973333-27.306667-25.6-49.493333-58.026667-61.44-88.746667z m0 0" fill="#FFFFFF" p-id="4390"></path><path d="M815.786667 539.306667c0-49.493333-39.253333-88.746667-85.333334-88.746667-23.893333 0-46.08 10.24-61.44 27.306667-15.36-17.066667-37.546667-27.306667-61.44-27.306667-47.786667 0-85.333333 40.96-85.333333 88.746667v6.826666c0 8.533333 1.706667 18.773333 6.826667 29.013334v1.706666c25.6 63.146667 128 134.826667 131.413333 138.24 3.413333 1.706667 5.12 3.413333 8.533333 3.413334s6.826667-1.706667 8.533334-3.413334c3.413333-3.413333 90.453333-64.853333 124.586666-122.88 1.706667-1.706667 1.706667-3.413333 3.413334-5.12v-1.706666c1.706667-3.413333 3.413333-8.533333 5.12-11.946667 3.413333-8.533333 5.12-17.066667 5.12-25.6V546.133333v-6.826666z m0 0" fill="#FFFFFF" p-id="4391"></path></svg>'
        }, link: 'https://afdian.tv/item/52230b2860a011f083ef52540025c377'
      },
      {
        icon: {
          svg: '<svg t="1752550100623" class="icon" viewBox="0 0 1110 1024" version="1.1" xmlns="http://www.w3.org/2000/svg" p-id="17972" width="200" height="200"><path d="M572.377762 54.631569l409.570556 368.207469v580.792847H109.025692v-580.792847z" fill="#E8E8E8" p-id="17973"></path><path d="M567.586102 0L338.616951 191.063276V69.296232H165.889254v265.93474L0 490.012503l112.967296 121.776541 449.63719-400.756562 435.917561 390.983286 112.017512-112.003265z" fill="#EB7A7A" p-id="17974"></path><path d="M41.847478 942.556032h1004.828612v81.439219H41.847478z" fill="#D9D9D9" p-id="17975"></path><path d="M576.936724 395.584989h-3.936854s-354.616061 3.765893 0 508.371826h3.936854c354.625559-504.605932 0-508.371826 0-508.371826z m-3.457213 182.391749c-33.028735 0-59.803142-26.774408-59.803142-59.803143s26.774408-59.803142 59.803142-59.803142c33.023986 0 59.798394 26.774408 59.798394 59.803142-0.004749 33.028735-26.774408 59.803142-59.798394 59.803143z" fill="#00CCC6" p-id="17976"></path></svg>'
        },
        link: 'https://godothub.com',
        ariaLabel: 'Godot Hub'
      }
    ],
    footer: {
      message: 'Released under BSD3-Clause License.',
      copyright: 'Copyright © 2025 Konado Project. <br>All rights reserved.'
    }
  },

  locales: {

    root: {
      label: '简体中文',
      lang: 'zh-CN',
      description: 'Konado: 视觉小说框架',
      themeConfig: {
        lastUpdatedText: '最后更新于',
        editLink: {
          pattern: 'https://github.com/godothub/konado/edit/master/docs/:path',
          text: '在线编辑此页'
        },
        outlineTitle: '本页目录',
        returnToTopLabel: '返回顶部',
        darkModeSwitchLabel: '深色模式',
        docFooter: {
          prev: '上一页',
          next: '下一页'
        },
        search: {
          provider: 'local',
          options: {
            translations: {
              button: {
                buttonText: '搜索',
                buttonAriaLabel: '搜索'
              },
              modal: {
                footer: {
                  selectText: '选择',
                  navigateText: '切换',
                  closeText: '关闭'
                }
              }
            }
          }
        },
        nav: [
          {
            text: '查看文档', link: '/tutorial/install'
          },
          {
            text: '下载插件', link: 'https://github.com/GodotHub/konado/releases/latest'
          },
          {
            text: '加入群聊', link: 'https://pd.qq.com/g/GodotHub999/text/707799746'
          },
          {
            text: '赞助我们', link: 'https://afdian.tv/item/52230b2860a011f083ef52540025c377'
          }
        ],
        sidebar: [
          {
            text: '基础教程',
            items: [
              { text: '安装Konado', link: '/tutorial/install' },
              { text: '对话配置文件', link: '/tutorial/profiles' },
              { text: '演员坐标与缩放', link: '/tutorial/actor-coordinate-and-scaling' },
              { text: '自定义对话框', link: '/tutorial/customize-the-dialogbox' }
            ]
          },
          {
            text: 'Konado Script',
            items: [
              { text: '脚本介绍', link: '/script/konado-script' },
              { text: '元数据', link: '/script/meta-data' },
              { text: '普通对话', link: '/script/conversation' },
              {
                text: '背景',
                collapsed: true,
                items: [
                  { text: '背景切换', link: '/script/background-switch' }
                ]
              },
              {
                text: '演员',
                collapsed: true,
                items: [
                  { text: '创建演员', link: '/script/create-actor' },
                  { text: '演员退场', link: '/script/actor-leave' },
                  { text: '演员移动', link: '/script/actor-move' },
                  { text: '演员切换状态', link: '/script/actor-change-state' }
                ]
              },
              {
                text: '交互',
                collapsed: true,
                items: [
                  { text: '标签', link: '/script/label' },
                  { text: '选项跳转', link: '/script/option-to-jump' },
                ]
              },
              {
                text: '音频',
                collapsed: true,
                items: [
                  { text: '播放背景音乐', link: '/script/' },
                  { text: '停止背景音乐', link: '/script/' },
                  { text: '播放音效', link: '/script/' }
                ]
              },
              {
                text: '结束',
                collapsed: true,
                items: [
                  { text: '结束对话', link: '/script/' }
                ]
              }
            ]
          },
          {
            text: '开发',
            items: [
              {
                text: '核心功能指南', items: [
                  { text: '对话数据', link: '/develop/core/shot-and-dialogue.md' },
                  { text: '背景切换特效', link: '/develop/core/bg-trans-effect.md' },
                  { text: 'Logger', link: '/develop/core/logger.md' },
                ]
              },
              { text: '版本规划', link: '/develop/roadmap' },
              { text: '代码贡献', link: '/develop/code-contribute' },
              { text: '文档贡献', link: '/develop/doc-contribute' },
              { text: '翻译贡献', link: '/develop/translate-contribute' },
              { text: '问题反馈', link: '/develop/feedback' }
            ]
          },
          {
            text: 'Konado .NET API',
            items: [
              { text: '安装', link: '/konadotnet/install_konadotnet' },
              { text: '使用API', link: '/konadotnet/konadotnet_api' }
            ]

          },
          {
            text: '关于',
            items: [
              { text: '关于Konado', link: '/about/konado' },
              { text: '看板娘Kona', link: '/about/kona' },
              { text: '海报', link: '/about/banner' },
              { text: '许可证', link: '/about/license' },
              { text: '鸣谢', link: '/about/thanks' }
            ]
          }
        ]
      }
    },

    tc: {
      label: '繁體中文',
      lang: 'zh-CN',
      description: 'Konado: 視覺小說框架',
      themeConfig: {
        lastUpdatedText: '最後更新於',
        editLink: {
          pattern: 'https://github.com/godothub/konado/edit/master/docs/:path',
          text: '在線編輯此頁'
        },
        outlineTitle: '本頁目錄',
        returnToTopLabel: '返回頂部',
        darkModeSwitchLabel: '深色模式',
        docFooter: {
          prev: '上一頁',
          next: '下一頁'
        },
        search: {
          provider: 'local',
          options: {
            translations: {
              button: {
                buttonText: '搜索',
                buttonAriaLabel: '搜索'
              },
              modal: {
                footer: {
                  selectText: '選擇',
                  navigateText: '切換',
                  closeText: '關閉'
                }
              }
            }
          }
        },
        nav: [
          {
            text: '查看文檔', link: '/tc/tutorial/install'
          },
          {
            text: '下載插件', link: 'https://github.com/GodotHub/konado/releases/latest'
          },
          {
            text: '加入群聊', link: 'https://pd.qq.com/g/GodotHub999/text/707799746'
          },
          {
            text: '贊助我們', link: 'https://afdian.tv/item/52230b2860a011f083ef52540025c377'
          }
        ],
        sidebar: [
          {
            text: '基礎教程',
            items: [
              { text: '安裝Konado', link: '/tc/tutorial/install' },
              { text: '對話配置文件', link: '/tc/tutorial/profiles' },
              { text: '演員坐標與縮放', link: '/tc/tutorial/actor-coordinate-and-scaling' },
              { text: '自定義對話框', link: '/tc/tutorial/customize-the-dialogbox' }
            ]
          },
          {
            text: 'Konado Script',
            items: [
              { text: '腳本介紹', link: '/tc/script/konado-script' },
              { text: '元數據', link: '/tc/script/meta-data' },
              { text: '普通對話', link: '/tc/script/conversation' },
              {
                text: '背景',
                collapsed: true,
                items: [
                  { text: '背景切換', link: '/tc/script/background-switch' }
                ]
              },
              {
                text: '演員',
                collapsed: true,
                items: [
                  { text: '創建演員', link: '/tc/script/create-actor' },
                  { text: '演員退場', link: '/tc/script/actor-leave' },
                  { text: '演員移動', link: '/tc/script/actor-move' },
                  { text: '演員切換狀態', link: '/tc/script/actor-change-state' }
                ]
              },
              {
                text: '交互',
                collapsed: true,
                items: [
                  { text: '標簽', link: '/tc/script/label' },
                  { text: '選項跳轉', link: '/tc/script/option-to-jump' },
                ]
              },
              {
                text: '音頻',
                collapsed: true,
                items: [
                  { text: '播放背景音樂', link: '/tc/script/' },
                  { text: '停止背景音樂', link: '/tc/script/' },
                  { text: '播放音效', link: '/tc/script/' }
                ]
              },
              {
                text: '結束',
                collapsed: true,
                items: [
                  { text: '結束對話', link: '/tc/script/' }
                ]
              }
            ]
          },
          {
            text: '開發',
            items: [
              {
                text: '核心功能指南', items: [
                  { text: '對話數據', link: '/tc/develop/core/shot-and-dialogue.md' },
                  { text: '背景切換特效', link: '/tc/develop/core/bg-trans-effect.md' },
                  { text: 'Logger', link: '/tc/develop/core/logger.md' },
                ]
              },
              { text: '版本規劃', link: '/tc/develop/roadmap' },
              { text: '代碼貢獻', link: '/tc/develop/code-contribute' },
              { text: '文檔貢獻', link: '/tc/develop/doc-contribute' },
              { text: '翻譯貢獻', link: '/tc/develop/translate-contribute' },
              { text: '問題反饋', link: '/tc/develop/feedback' }
            ]
          },
          {
            text: 'Konado .NET API',
            items: [
              { text: '安裝', link: '/tc/konadotnet/install_konadotnet' },
              { text: '使用API', link: '/tc/konadotnet/konadotnet_api' }
            ]

          },
          {
            text: '關於',
            items: [
              { text: '關於Konado', link: '/tc/about/konado' },
              { text: '看板娘Kona', link: '/tc/about/kona' },
              { text: '海報', link: '/tc/about/banner' },
              { text: '許可證', link: '/tc/about/license' },
              { text: '鳴謝', link: '/tc/about/thanks' }
            ]
          }
        ]
      }
    },

    en: {
      label: 'English',
      lang: 'en',
      description: 'Konado: Visual Novel Framework',
      themeConfig: {
        lastUpdatedText: 'Last updated on',
        editLink: {
          pattern: 'https://github.com/godothub/konado/edit/master/docs/:path',
          text: 'Edit this page online'
        },
        nav: [
          {
            text: 'Documentation', link: '/en/tutorial/install'
          },
          // {
          //   text: '更新日志', link: '/update'
          // },
          {
            text: 'Join Chat', link: 'https://discord.gg/XJVSf4eHaC'
          },
          {
            text: 'Sponsor Us', link: 'https://afdian.tv/item/52230b2860a011f083ef52540025c377'
          }
        ],
        sidebar: [
          {
            text: 'Tutorial',
            items: [
              { text: 'Install', link: '/en/tutorial/install' },
              { text: '对话配置文件', link: '/en/tutorial/profiles' },
              { text: '演员坐标与缩放', link: '/en/tutorial/actor-coordinate-and-scaling' },
              { text: '自定义对话框', link: '/en/tutorial/customize-the-dialogbox' }
            ]
          },
          {
            text: 'Konado Script',
            items: [
              { text: '脚本介绍', link: '/en/script/konado-script' },
              { text: '元数据', link: '/en/script/meta-data' },
              { text: '普通对话', link: '/en/script/conversation' },
              {
                text: '背景',
                collapsed: true,
                items: [
                  { text: '背景切换', link: '/en/script/background-switch' }
                ]
              },
              {
                text: '演员',
                collapsed: true,
                items: [
                  { text: '创建演员', link: '/en/script/create-actor' },
                  { text: '演员退场', link: '/en/script/actor-leave' },
                  { text: '演员移动', link: '/en/script/actor-move' },
                  { text: '演员切换状态', link: '/en/script/actor-change-state' }
                ]
              },
              {
                text: '交互',
                collapsed: true,
                items: [
                  { text: '分支', link: '/en/script/branch' },
                  { text: '选项跳转', link: '/en/script/option-to-jump' },
                ]
              },
              {
                text: '音频',
                collapsed: true,
                items: [
                  { text: '播放背景音乐', link: '/en/script/' },
                  { text: '停止背景音乐', link: '/en/script/' },
                  { text: '播放音效', link: '/en/script/' }
                ]
              },
              {
                text: '结束',
                collapsed: true,
                items: [
                  { text: '结束对话', link: '/en/script/' }
                ]
              }
            ]
          },
          {
            text: ' Konado .NET',
            items: [
              { text: '安装konadotnet', link: '/en/konadotnet/install_konadotnet' },
              {
                text: 'KonadoAPI',
                collapsed: true,
                items: [
                  { text: 'KonadoAPI介绍', link: '/en/konadotnet/konadoapi' },
                  { text: 'KonadoAPI使用', link: '/en/konadotnet/konadoapi_use' },
                  { text: '对话管理', link: '/en/konadotnet/konadoapi_example' },
                  { text: 'KonadoAPI示例', link: '/en/konadotnet/konadoapi_example' }
                ]
              }
            ]

          },
          {
            text: '开发',
            items: [
              { text: '版本规划', link: '/en/develop/roadmap' },
              { text: '代码贡献', link: '/en/develop/code-contribute' },
              { text: '文档贡献', link: '/en/develop/doc-contribute' },
              { text: '翻译贡献', link: '/en/develop/translate-contribute' },
              { text: '问题反馈', link: '/en/develop/feedback' }
            ]
          },
          {
            text: 'About',
            items: [
              { text: 'Konado', link: '/en/about/konado' },
              { text: 'Kona', link: '/en/about/kona' },
              { text: '许可证', link: '/en/about/license' },
              { text: '鸣谢', link: '/en/about/thanks' }
            ]
          }
        ]
      }
    }
  }
})
