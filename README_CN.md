# MQL5-JsonLib: 专业级MQL5 JSON库

![Version](https://img.shields.io/badge/version-11.0-blue.svg) ![License](https://img.shields.io/badge/license-MIT-green.svg) ![Platform](https://img.shields.io/badge/platform-MetaTrader%205-orange.svg)

**MQL5-JsonLib** 是一个功能全面、性能卓越且高度健壮的JSON解决方案，专为 MQL5 语言设计。它提供了从简单的 DOM 解析、数据绑定到复杂的 SAX 流式处理和强大的 JSONPath 查询等一系列专业级功能，旨在为 MQL5 开发者提供一个完全现代化的数据交换与处理工具。

无论您是需要对接 Web API 获取市场数据、管理复杂的 EA/指标配置，还是在不同系统间高效交换信息，JsonLib 都能提供一个稳定、高效且极其易用的接口。

## 核心特性

* ⚡️ **双引擎解析**:
  * `ENGINE_HIGH_SPEED`: 针对标准 RFC 8259 格式优化的超高速解析器。
  * `ENGINE_STANDARD`: 功能完整的流式解析器，支持注释、尾随逗号等非标准特性。
  * `ENGINE_AUTO` (默认): 智能切换引擎，在确保兼容性的同时提供最佳性能。
* 🌳 **完整的文档对象模型 (DOM) API**: 像操作普通 MQL5 对象一样，轻松加载、创建、访问和修改 JSON 文档。
* 🌊 **高效的流式 (SAX) API**: 以极低的内存占用处理GB级别的超大 JSON 文件，是处理大数据流的理想选择。
* 🔎 **强大的数据查询**:
  * **JSONPath**: 使用类似 XPath 的语法，从复杂的 JSON 结构中轻松查询和提取数据。
  * **JSON Pointer (RFC 6901)**: 提供轻量、快速的单点元素定位。
* 💾 **无缝文件 I/O**: 直接从文件流高效解析 JSON，或将内存中的 JSON 文档以美观或紧凑的格式保存到文件。
* 🔗 **强大的数据绑定 (`JsonMapper`)**: 实现 MQL5 自定义类与 JSON 节点之间的自动双向映射，极大提升代码的结构化和可维护性。
* 🛠️ **高级文档操作**:
  * **深度合并 (Deep Merge)**: 递归合并两个 JSON 对象，是聚合配置的利器。
  * **RFC 7396 Patch**: 支持标准化的 JSON Patch 协议，用于对 JSON 文档进行精确的局部更新。
* ⚠️ **健壮的错误处理**: 提供详尽的错误信息，包括行号、列号和上下文，帮助开发者快速定位并解决问题。

## 性能亮点

本库经过严格的性能测试。在 MetaTrader 5 Build `5233` 环境下，针对不同大小的 JSON 文件，其吞吐能力表现卓越：

| 文件大小 (实际)   | JsonFromFile (流式) | JsonParse (标准内存) | JsonParse (高速内存) |
|:----------- |:----------------- |:---------------- |:---------------- |
| **7.6 KB**  | `23.49 MB/s`      | `30.93 MB/s`     | **`34.37 MB/s`** |
| **62.5 KB** | `28.42 MB/s`      | `31.81 MB/s`     | **`35.57 MB/s`** |
| **1.0 MB**  | `9.80 MB/s`       | `9.45 MB/s`      | **`9.91 MB/s`**  |
| **15.4 MB** | `0.66 MB/s`       | `0.67 MB/s`      | **`0.68 MB/s`**  |

> **结论**: 在处理<1MB的中小文件时，高速引擎性能优势明显。对于超大文件，流式解析 (`JsonFromFile`) 能在保证极低内存占用的同时提供稳定的高性能。

## 安装指南

1. 将 `JsonLib.mqh` 文件和 `Core` 文件夹完整复制到您的 MQL5 `Include` 目录下 (路径通常是 `MQL5/Include/`)。
2. 在您的 EA、脚本或指标代码中，仅需包含主头文件即可开始使用：
   
   ```mql5
   #include <JsonLib.mqh>
   ```

## 快速入门：5分钟掌握核心用法

下面的示例将带您快速体验解析 JSON、读取数据、修改数据并打印的全过程。

```mql5
#include <JsonLib.mqh>

void OnStart()
{
    // 1. 假设这是从Web API获取的行情数据
    string market_data_str = R"({
      "symbol": "EURUSD",
      "timestamp": 1672531200,
      "bid": 1.0705,
      "ask": 1.0708,
      "tradeable": true,
      "levels": [1.0700, 1.0800]
    })";

    // 2. 解析JSON字符串
    MQL5_Json::JsonError error;
    MQL5_Json::JsonDocument doc = MQL5_Json::JsonParse(market_data_str, error);

    // 3. 校验并访问数据
    if(doc.IsValid())
    {
        MQL5_Json::JsonNode root = doc.GetRoot();

        // 使用 [] 操作符和 As...() 方法安全地读取数据
        string symbol = root["symbol"].AsString("N/A");
        double spread = root["ask"].AsDouble() - root["bid"].AsDouble();

        PrintFormat("Symbol: %s, Spread: %.5f", symbol, spread);

        // 4. 修改数据
        root.Set("tradeable", false); // 假设我们暂停交易该品种
        root.SetObject("metadata").Set("source", "My EA"); // 添加新的子对象

        // 5. 将修改后的文档转换为格式化的字符串并打印
        Print("\n--- Modified JSON ---");
        Print(doc.ToString(true));
    }
    else
    {
        Print("JSON parsing failed: ", error.ToString());
    }
}
```

## 权威API指南

---

### **Part 1: DOM API 核心用法**

#### **1.1 解析JSON**

**示例 1: 从字符串解析 (支持非标准格式)**

```mql5
// 假设JSON来自一个允许注释的配置文件
string text_with_comments = R"({
    "strategy_id": "MA_Cross_v2", // 策略标识符
    "magic_number": 654321,
})";

MQL5_Json::JsonError error;
MQL5_Json::JsonParseOptions options;
options.engine = MQL5_Json::ENGINE_STANDARD;     // 必须使用标准引擎以支持注释
options.allow_comments = true;                  // 允许注释
options.allow_trailing_commas = true;           // 同时允许尾随逗号

MQL5_Json::JsonDocument doc = MQL5_Json::JsonParse(text_with_comments, error, options);
Print("Magic Number: ", doc["magic_number"].AsInt());
```

**示例 2: 从文件高效解析 (推荐)**
此方法内存效率极高，是读取配置或数据文件的最佳选择。

```mql5
string filename = "ea_settings.json";
// (此处省略写入文件的代码...)

MQL5_Json::JsonError error;
MQL5_Json::JsonDocument config_doc = MQL5_Json::JsonFromFile(filename, error);

if(config_doc.IsValid()) {
    Print("Successfully loaded config from ", filename);
}
```

---

#### **1.2 创建全新的JSON文档**

**示例: 构建一个完整的EA交易参数配置**

```mql5
MQL5_Json::JsonDocument doc = MQL5_Json::JsonNewObject();
MQL5_Json::JsonNode root = doc.GetRoot();

root.Set("ea_name", "Pro RSI Trader");
root.Set("version", 1.2);
root.Set("enabled", true);

// 添加一个包含基本参数的子对象
MQL5_Json::JsonNode params = root.SetObject("parameters");
params.Set("rsi_period", 14);
params.Set("stop_loss_pips", 50);
params.Set("take_profit_pips", 100);

// 添加一个包含风险控制设置的子对象
MQL5_Json::JsonNode risk = root.SetObject("risk_management");
risk.Set("max_drawdown_percent", 20.0);
risk.Set("lot_sizing_method", "fixed");
risk.Set("fixed_lot_size", 0.02);

// 添加一个允许交易的时间段数组
MQL5_Json::JsonNode trading_sessions = root.SetArray("trading_sessions");
trading_sessions.Add("London");
trading_sessions.Add("New_York");

Print(doc.ToString(true));
```

---

#### **1.3 访问与读取数据**

**示例: 解析一个包含多层嵌套的账户信息JSON**

```mql5
string account_info_str = R"({
  "accountId": "USR-9876",
  "balance": 10250.75,
  "leverage": 100,
  "isActive": true,
  "contact": {
    "email": "trader@example.com",
    "phone": null
  },
  "openPositions": [
    {"ticket": 1, "symbol": "EURUSD", "profit": 150.25},
    {"ticket": 2, "symbol": "GBPUSD", "profit": -75.50}
  ]
})";

MQL5_Json::JsonDocument doc = MQL5_Json::JsonParse(account_info_str);
MQL5_Json::JsonNode root = doc.GetRoot();

// 读取基本类型
double balance = root["balance"].AsDouble(0.0);

// 读取嵌套对象中的值
string email = root["contact"]["email"].AsString("N/A");

// 检查节点是否存在或为null
if (root["contact"]["phone"].IsNull()) {
    Print("Phone number is not provided.");
}

// 遍历数组
double total_profit = 0;
MQL5_Json::JsonNode positions = root["openPositions"];
if (positions.IsArray()) {
    for (int i = 0; i < positions.Size(); i++) {
        total_profit += positions[i]["profit"].AsDouble();
    }
}
PrintFormat("Account %s | Balance: %.2f | Total Floating Profit: %.2f", 
    root["accountId"].AsString(), balance, total_profit);
```

---

#### **1.4 修改与更新数据**

**示例: 动态调整一个策略配置**

```mql5
string config_str = "{\"risk_percent\": 1.0, \"symbols\": [\"EURUSD\", \"USDJPY\"]}";
MQL5_Json::JsonDocument doc = MQL5_Json::JsonParse(config_str);
MQL5_Json::JsonNode root = doc.GetRoot();

// 1. 更新一个值
root.Set("risk_percent", 1.5);

// 2. 向数组中添加一个新元素
root["symbols"].Add("AUDUSD");

// 3. 添加一个全新的键值对
root.Set("comment", "Optimized on 2025.08.29");

// 4. 从数组中移除一个元素 (假设要移除 "USDJPY")
MQL5_Json::JsonNode symbols_node = root["symbols"];
for(int i = symbols_node.Size() - 1; i >= 0; i--) {
    if(symbols_node[i].AsString() == "USDJPY") {
        symbols_node.Remove(i);
        break;
    }
}
Print(doc.ToString(true));
```

---

#### **1.5 序列化 (将JSON转为字符串)**

**示例: 创建并以不同格式导出JSON**

```mql5
MQL5_Json::JsonDocument doc = MQL5_Json::JsonNewObject();
doc.GetRoot().Set("user", "test");
doc.GetRoot().SetObject("data").Set("value", 100);

// 紧凑格式: 适合通过网络API传输，体积最小
string compact_string = doc.ToString(false);
Print("Compact String: ", compact_string);

// 格式化: 适合存入配置文件，或用于调试，便于阅读
string pretty_string = doc.ToString(true);
Print("Pretty String:\n", pretty_string);
```

---

### **Part 2: 高级查询与操作**

#### **2.1 JSONPath 强大查询**

**示例: 从一个复杂的财经新闻API响应中提取关键信息**

```mql5
#include <JsonLib.mqh> // JsonQuery 命名空间位于此文件中

void OnStart()
{
    string news_api_response = R"({
      "provider": "NewsFeed Inc.",
      "articles": [
        { "id": 101, "headline": "Fed holds rates steady", "impact": "High", "region": "USA" },
        { "id": 102, "headline": "ECB hints at future cuts", "impact": "High", "region": "EU" },
        { "id": 103, "headline": "Tech earnings surprise", "impact": "Low", "region": "USA" }
      ]
    })";

    MQL5_Json::JsonDocument doc = MQL5_Json::JsonParse(news_api_response);
    MQL5_Json::JsonNode root = doc.GetRoot();
    JsonError error;

    // 查询所有“High” impact新闻的标题
    MQL5_Json::JsonNode high_impact_news[];
    string path = "$.articles[?(@.impact == 'High')].headline";
    int count = MQL5_Json::JsonQuery::SelectNodes(root, path, high_impact_news, error);

    Print("--- High Impact News Headlines ---");
    for (int i=0; i<count; i++) Print("> ", high_impact_news[i].AsString());
}
```

#### **2.2 JSON Pointer (RFC 6901) 精准定位**

当您清楚地知道目标元素的确切路径时，JSON Pointer 是一种比JSONPath更轻量、更快的访问方式。

```mql5
string text = R"({
  "account": { "details": { "user_id": 12345 }},
  "orders": [ {"id": "A1"}, {"id": "B2"} ]
})";

MQL5_Json::JsonNode root = MQL5_Json::JsonParse(text).GetRoot();
MQL5_Json::JsonNode user_id = root.QueryPointer("/account/details/user_id");
MQL5_Json::JsonNode second_order_id = root.QueryPointer("/orders/1/id");

PrintFormat("User ID: %d, Second Order ID: %s", (int)user_id.AsInt(), second_order_id.AsString());
```

---

#### **2.3 深度合并 (Merge) 与 RFC 7396 补丁 (Patch)**

**示例: 深度合并 (`Merge`)** - 合并默认配置和用户自定义配置。

```mql5
string default_cfg_str = "{\"settings\": {\"sound_alerts\": true}, \"risk_level\": 1}";
MQL5_Json::JsonDocument default_doc = MQL5_Json::JsonParse(default_cfg_str);
string user_cfg_str = "{\"settings\": {\"sound_alerts\": false}, \"user_id\": \"my_user\"}";
MQL5_Json::JsonDocument user_doc = MQL5_Json::JsonParse(user_cfg_str);

MQL5_Json::JsonDocument final_doc = MQL5_Json::JsonQuery::Merge(default_doc, user_doc);
Print(final_doc.ToString(true));
```

**示例: RFC 7396 补丁 (`Patch`)** - 更新和删除字段。

```mql5
string base_str = "{\"lot_size\": 0.1, \"magic_number\": 123, \"comment\": \"active\"}";
MQL5_Json::JsonDocument base_doc = MQL5_Json::JsonParse(base_str);
string patch_str = "{\"magic_number\": 456, \"comment\": null}"; // null表示删除
MQL5_Json::JsonDocument patch_doc = MQL5_Json::JsonParse(patch_str);
base_doc.Patch(patch_doc);
Print(base_doc.ToString(true));
```

---

### **Part 3: 高级编程模式**

#### **3.1 数据绑定 (`JsonMapper`)**

**示例: 将一个完整的交易策略配置映射到一个MQL5类中，包含嵌套对象和数组。**

```mql5
#include <JsonLib.mqh>

// --- 子对象类: 指标设置 ---
class CIndicatorSettings : public MQL5_Json::IJsonSerializable { /* ... (定义见上一版示例) ... */ };
// --- 主配置类 ---
class CStrategyConfig : public MQL5_Json::IJsonSerializable { /* ... (定义见上一版示例) ... */ };

// --- 使用 Mapper 进行解耦和类型安全的操作 ---
void OnStart()
{
    string config_json = /* ... (一个复杂的配置JSON字符串) ... */;
    CStrategyConfig config;
    if (MQL5_Json::JsonMapper::Deserialize(MQL5_Json::JsonParse(config_json).GetRoot(), config))
    {
        Print("Configuration loaded successfully into CStrategyConfig object.");
    }
}
```

#### **3.2 流式解析 (SAX API): 处理超大JSON文件**

**示例: 从一个巨大的交易日志流中，统计总盈利和亏损交易的次数。**

```mql5
// 1. 定义一个自定义事件处理器
class CTradeLogHandler : public MQL5_Json::IJsonStreamHandler
{ /* ... (定义见上一版示例) ... */ };

// 2. 使用流式解析器
void OnStart()
{
    // 假设 huge_log_stream 来自一个大文件或网络响应
    string huge_log_stream = "{\"trades\": [{\"profit\": 10}, {\"profit\": -5}, ...]}";
    CTradeLogHandler handler;
    JsonError error;
    if (MQL5_Json::JsonStreamParse(huge_log_stream, GetPointer(handler), error))
    {
        PrintFormat("Analysis complete. Profitable trades: %d, Losing trades: %d", 
            handler.m_profitable_trades, handler.m_losing_trades);
    }
}
```

---

## 错误处理

**示例：捕获并解读一个典型的JSON语法错误**

```mql5
string bad_json = "{\"symbol\": \"EURUSD\" \"price\": 1.07}"; // 缺少逗号
MQL5_Json::JsonError error;
MQL5_Json::JsonDocument doc = MQL5_Json::JsonParse(bad_json, error);

if (!doc.IsValid())
{
    Print("--- JSON Parse Error Report ---");
    Print("Message:    ", error.message);
    Print("Location:   ", "Line ", error.line, ", Col ", error.column);
    Print("Context:    ", error.context);
    Print("\nFull Report:\n", error.ToString());
}
```

---

## 贡献

本库由 **ding9736** 开发和维护。我们欢迎社区的贡献，无论是问题反馈还是代码提交。

* **MQL5 Profile**: [https://www.mql5.com/en/users/ding9736](https://www.mql5.com/en/users/ding9736)
* **GitHub Repository**: [https://github.com/ding9736/MQL5-JsonLib](https://github.com/ding9736/MQL5-JsonLib)

---

## License

[MIT License](LICENSE)

```
MIT License

Copyright (c) 2025 ding9736

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
