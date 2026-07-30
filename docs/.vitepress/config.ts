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
            { text: "安全说明", link: "/guide/security" },
          ],
        },
      ],
    },

    socialLinks: [
      {
        icon: "github",
        link: "https://github.com/GuEe0312/CloudScripts",
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
