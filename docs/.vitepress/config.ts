import { defineConfig } from "vitepress";

export default defineConfig({
  title: "CloudScripts",
  description: "皮卡在线脚本托管平台 - 一站式服务器管理脚本",
  lang: "zh-CN",
  lastUpdated: true,

  themeConfig: {
    logo: "/logo.svg",

    nav: [
      { text: "首页", link: "/" },
      { text: "使用指南", link: "/guide/getting-started" },
    ],

    sidebar: {
      "/guide/": [
        {
          text: "指南",
          items: [
            { text: "快速开始", link: "/guide/getting-started" },
            { text: "Linux 脚本", link: "/guide/linux-scripts" },
            { text: "Windows 脚本", link: "/guide/windows-scripts" },
            { text: "镜像通道", link: "/guide/mirror" },
            { text: "服务托管", link: "/guide/service" },
            { text: "多语言", link: "/guide/i18n" },
            { text: "安全说明", link: "/guide/security" },
            { text: "故障排除", link: "/guide/troubleshooting" },
            { text: "卸载回滚", link: "/guide/uninstall" },
          ],
        },
      ],
    },

    socialLinks: [
      {
        icon: "github",
        link: "https://github.com/PIKACHUIM/CloudScripts",
      },
    ],

    footer: {
      message: "基于 GNU GPL v3 许可证发布",
      copyright: "Copyright © 2024 CloudScripts",
    },

    search: {
      provider: "local",
    },

    outline: {
      level: [2, 3],
      label: "页面导航",
    },

    docFooter: {
      prev: "上一页",
      next: "下一页",
    },

    lastUpdated: {
      text: "最后更新于",
    },

    darkModeSwitchLabel: "主题",
    sidebarMenuLabel: "菜单",
    returnToTopLabel: "回到顶部",
  },
});
