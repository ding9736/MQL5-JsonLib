# MQL5-JsonLib: A Professional-Grade JSON Library for MQL5

![Version](https://img.shields.io/badge/version-11.0-blue.svg) ![License](https://img.shields.io/badge/license-MIT-green.svg) ![Platform](https://img.shields.io/badge/platform-MetaTrader%205-orange.svg)

**MQL5-JsonLib** is a comprehensive, high-performance, and robust JSON solution designed specifically for the MQL5 language. It provides a full suite of professional-grade features, from simple DOM parsing and data binding to complex SAX-style stream processing and powerful JSONPath queries, aiming to equip MQL5 developers with a thoroughly modern tool for data exchange and manipulation.

Whether you need to interface with web APIs for market data, manage complex EA/indicator configurations, or exchange information efficiently between different systems, JsonLib offers a stable, high-performance, and exceptionally easy-to-use interface.

## Core Features

* ⚡️ **Dual-Engine Parsing**:
  * `ENGINE_HIGH_SPEED`: An ultra-fast parser optimized for standard RFC 8259-compliant JSON.
  * `ENGINE_STANDARD`: A feature-complete stream parser that supports non-standard features like comments and trailing commas.
  * `ENGINE_AUTO` (Default): Intelligently switches between engines to provide optimal performance while ensuring compatibility.
* 🌳 **Complete Document Object Model (DOM) API**: Easily load, create, access, and modify JSON documents as if they were native MQL5 objects.
* 🌊 **Efficient Stream-based (SAX) API**: Process gigabyte-scale JSON files with minimal memory footprint, ideal for handling large data streams.
* 🔎 **Powerful Data Queries**:
  * **JSONPath**: Effortlessly query and extract data from complex JSON structures using an XPath-like syntax.
  * **JSON Pointer (RFC 6901)**: Provides lightweight and fast pinpoint element access.
* 💾 **Seamless File I/O**: Efficiently parse JSON directly from a file stream, or save in-memory JSON documents to files in either pretty or compact format.
* 🔗 **Robust Data Binding (`JsonMapper`)**: Enables automatic, bidirectional mapping between MQL5 custom classes and JSON nodes, significantly improving code structure and maintainability.
* 🛠️ **Advanced Document Operations**:
  * **Deep Merge**: Recursively merge two JSON objects, a powerful tool for aggregating configurations.
  * **RFC 7396 Patch**: Supports the standardized JSON Patch protocol for performing precise, partial updates to JSON documents.
* ⚠️ **Robust Error Handling**: Provides detailed error messages, including line number, column, and context, to help developers quickly locate and resolve issues.

## Performance Highlights

This library has undergone rigorous performance testing. Under the MetaTrader 5 Build `5233` environment, its throughput when handling JSON files of various sizes is exceptional:

| File Size (Actual) | JsonFromFile (Stream) | JsonParse (Standard Mem) | JsonParse (Rapid Mem) |
|:------------------ |:--------------------- |:------------------------ |:--------------------- |
| **7.6 KB**         | `23.49 MB/s`          | `30.93 MB/s`             | **`34.37 MB/s`**      |
| **62.5 KB**        | `28.42 MB/s`          | `31.81 MB/s`             | **`35.57 MB/s`**      |
| **1.0 MB**         | `9.80 MB/s`           | `9.45 MB/s`              | **`9.91 MB/s`**       |
| **15.4 MB**        | `0.66 MB/s`           | `0.67 MB/s`              | **`0.68 MB/s`**       |

> **Conclusion**: For small to medium-sized files (<1MB), the high-speed engine demonstrates a significant performance advantage. For very large files, stream-based parsing (`JsonFromFile`) delivers stable, high performance while guaranteeing minimal memory usage.

## Installation Guide

1. Copy the `JsonLib.mqh` file and the entire `Core` folder into your MQL5 `Include` directory (typically located at `MQL5/Include/`).
2. In your EA, script, or indicator code, simply include the main header file to get started:
   
   ```mql5
   #include <JsonLib.mqh>
   ```

## Quick Start: Master the Basics in 5 Minutes

The example below will walk you through the entire process of parsing JSON, reading data, modifying it, and printing the result.

```mql5
#include <JsonLib.mqh>

void OnStart()
{
    // 1. Imagine this is market data from a web API
    string market_data_str = R"({
      "symbol": "EURUSD",
      "timestamp": 1672531200,
      "bid": 1.0705,
      "ask": 1.0708,
      "tradeable": true,
      "levels": [1.0700, 1.0800]
    })";

    // 2. Parse the JSON string
    MQL5_Json::JsonError error;
    MQL5_Json::JsonDocument doc = MQL5_Json::JsonParse(market_data_str, error);

    // 3. Validate and access the data
    if(doc.IsValid())
    {
        MQL5_Json::JsonNode root = doc.GetRoot();

        // Safely read data using the [] operator and As...() methods
        string symbol = root["symbol"].AsString("N/A");
        double spread = root["ask"].AsDouble() - root["bid"].AsDouble();

        PrintFormat("Symbol: %s, Spread: %.5f", symbol, spread);

        // 4. Modify the data
        root.Set("tradeable", false); // Let's assume we pause trading for this pair
        root.SetObject("metadata").Set("source", "My EA"); // Add a new child object

        // 5. Convert the modified document back to a formatted string and print it
        Print("\n--- Modified JSON ---");
        Print(doc.ToString(true));
    }
    else
    {
        Print("JSON parsing failed: ", error.ToString());
    }
}
```

## Authoritative API Guide

---

### **Part 1: Core DOM API Usage**

#### **1.1 Parsing JSON**

**Example 1: Parsing from a String (with non-standard format support)**

```mql5
// Assume the JSON comes from a configuration file that allows comments
string text_with_comments = R"({
    "strategy_id": "MA_Cross_v2", // Strategy identifier
    "magic_number": 654321,
})";

MQL5_Json::JsonError error;
MQL5_Json::JsonParseOptions options;
options.engine = MQL5_Json::ENGINE_STANDARD;     // Must use the standard engine for comment support
options.allow_comments = true;                  // Allow comments
options.allow_trailing_commas = true;           // Also allow trailing commas

MQL5_Json::JsonDocument doc = MQL5_Json::JsonParse(text_with_comments, error, options);
Print("Magic Number: ", doc["magic_number"].AsInt());
```

**Example 2: Parsing from a File Efficiently (Recommended)**
This method is extremely memory-efficient and is the best choice for reading configurations or data files.

```mql5
string filename = "ea_settings.json";
// (Code to write the file is omitted here...)

MQL5_Json::JsonError error;
MQL5_Json::JsonDocument config_doc = MQL5_Json::JsonFromFile(filename, error);

if(config_doc.IsValid()) {
    Print("Successfully loaded config from ", filename);
}
```

---

#### **1.2 Creating New JSON Documents**

**Example: Building a complete EA trading parameter configuration from scratch**

```mql5
MQL5_Json::JsonDocument doc = MQL5_Json::JsonNewObject();
MQL5_Json::JsonNode root = doc.GetRoot();

root.Set("ea_name", "Pro RSI Trader");
root.Set("version", 1.2);
root.Set("enabled", true);

// Add a child object for basic parameters
MQL5_Json::JsonNode params = root.SetObject("parameters");
params.Set("rsi_period", 14);
params.Set("stop_loss_pips", 50);
params.Set("take_profit_pips", 100);

// Add a child object for risk management settings
MQL5_Json::JsonNode risk = root.SetObject("risk_management");
risk.Set("max_drawdown_percent", 20.0);
risk.Set("lot_sizing_method", "fixed");
risk.Set("fixed_lot_size", 0.02);

// Add an array of allowed trading sessions
MQL5_Json::JsonNode trading_sessions = root.SetArray("trading_sessions");
trading_sessions.Add("London");
trading_sessions.Add("New_York");

Print(doc.ToString(true));
```

---

#### **1.3 Accessing and Reading Data**

**Example: Parsing a multi-level account information JSON**

```mql5
string account_info_str = R"({
  "accountId": "USR-9876", "balance": 10250.75, "leverage": 100, "isActive": true,
  "contact": { "email": "trader@example.com", "phone": null },
  "openPositions": [
    {"ticket": 1, "symbol": "EURUSD", "profit": 150.25},
    {"ticket": 2, "symbol": "GBPUSD", "profit": -75.50}
  ]
})";

MQL5_Json::JsonDocument doc = MQL5_Json::JsonParse(account_info_str);
MQL5_Json::JsonNode root = doc.GetRoot();

// Read primitive types
double balance = root["balance"].AsDouble(0.0);

// Read a value from a nested object
string email = root["contact"]["email"].AsString("N/A");

// Check if a node is null or non-existent
if (root["contact"]["phone"].IsNull()) {
    Print("Phone number is not provided.");
}

// Iterate over an array
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

#### **1.4 Modifying and Updating Data**

**Example: Dynamically adjusting a strategy configuration**

```mql5
string config_str = "{\"risk_percent\": 1.0, \"symbols\": [\"EURUSD\", \"USDJPY\"]}";
MQL5_Json::JsonDocument doc = MQL5_Json::JsonParse(config_str);
MQL5_Json::JsonNode root = doc.GetRoot();

// 1. Update an existing value
root.Set("risk_percent", 1.5);

// 2. Add a new element to an existing array
root["symbols"].Add("AUDUSD");

// 3. Add a completely new key-value pair
root.Set("comment", "Optimized on 2025.08.29");

// 4. Remove an element from an array (e.g., remove "USDJPY")
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

#### **1.5 Serialization (Converting JSON to String)**

**Example: Creating and exporting JSON in different formats**

```mql5
MQL5_Json::JsonDocument doc = MQL5_Json::JsonNewObject();
doc.GetRoot().Set("user", "test");
doc.GetRoot().SetObject("data").Set("value", 100);

// Compact format: ideal for network transmission, minimum size
string compact_string = doc.ToString(false);
Print("Compact String: ", compact_string);

// Pretty format: ideal for configuration files or debugging, human-readable
string pretty_string = doc.ToString(true);
Print("Pretty String:\n", pretty_string);
```

---

### **Part 2: Advanced Queries and Operations**

#### **2.1 Powerful Queries with JSONPath**

**Example: Extracting key information from a complex financial news API response**

```mql5
#include <JsonLib.mqh> // The JsonQuery namespace is available here

void OnStart()
{
    string news_api_response = R"({
      "provider": "NewsFeed Inc.", "articles": [
        { "id": 101, "headline": "Fed holds rates steady", "impact": "High", "region": "USA" },
        { "id": 102, "headline": "ECB hints at future cuts", "impact": "High", "region": "EU" },
        { "id": 103, "headline": "Tech earnings surprise", "impact": "Low", "region": "USA" }
      ]
    })";

    MQL5_Json::JsonDocument doc = MQL5_Json::JsonParse(news_api_response);
    MQL5_Json::JsonNode root = doc.GetRoot();
    JsonError error;

    // Query for the headlines of all "High" impact news
    MQL5_Json::JsonNode high_impact_news[];
    string path = "$.articles[?(@.impact == 'High')].headline";
    int count = MQL5_Json::JsonQuery::SelectNodes(root, path, high_impact_news, error);

    Print("--- High Impact News Headlines ---");
    for (int i=0; i<count; i++) Print("> ", high_impact_news[i].AsString());
}
```

#### **2.2 Pinpoint Access with JSON Pointer (RFC 6901)**

When you know the exact path to an element, JSON Pointer is a more lightweight and faster alternative to JSONPath.

```mql5
string text = R"({"account": {"details": {"user_id": 12345}}, "orders": [{"id": "A1"}, {"id": "B2"}]})";

MQL5_Json::JsonNode root = MQL5_Json::JsonParse(text).GetRoot();

// Paths must start with '/' and use 0-based array indices
MQL5_Json::JsonNode user_id = root.QueryPointer("/account/details/user_id");
MQL5_Json::JsonNode second_order_id = root.QueryPointer("/orders/1/id");

PrintFormat("User ID: %d, Second Order ID: %s", (int)user_id.AsInt(), second_order_id.AsString());
```

---

#### **2.3 Deep Merge vs. RFC 7396 Patch**

**Scenario: Merging default settings with user-defined overrides**

**Example: Deep Merge**

```mql5
string default_cfg_str = "{\"settings\": {\"sound_alerts\": true}, \"risk_level\": 1}";
MQL5_Json::JsonDocument default_doc = MQL5_Json::JsonParse(default_cfg_str);
string user_cfg_str = "{\"settings\": {\"sound_alerts\": false}, \"user_id\": \"my_user\"}";
MQL5_Json::JsonDocument user_doc = MQL5_Json::JsonParse(user_cfg_str);

// User settings will override defaults and add new fields
MQL5_Json::JsonDocument final_doc = MQL5_Json::JsonQuery::Merge(default_doc, user_doc);
Print(final_doc.ToString(true));
```

**Example: RFC 7396 Patch**

```mql5
string base_str = "{\"lot_size\": 0.1, \"magic_number\": 123, \"comment\": \"active\"}";
MQL5_Json::JsonDocument base_doc = MQL5_Json::JsonParse(base_str);
string patch_str = "{\"magic_number\": 456, \"comment\": null}"; // 'null' value means delete the key
MQL5_Json::JsonDocument patch_doc = MQL5_Json::JsonParse(patch_str);
base_doc.Patch(patch_doc); // Apply patch directly
Print(base_doc.ToString(true));
```

---

### **Part 3: Advanced Programming Patterns**

#### **3.1 Data Binding with `JsonMapper`**

**Example: Mapping a complete strategy configuration to an MQL5 class, including nested objects and arrays.**

```mql5
#include <JsonLib.mqh>

// --- Child Object Class: Indicator Settings ---
class CIndicatorSettings : public MQL5_Json::IJsonSerializable { /* ... definition from previous example ... */ };
// --- Main Config Class ---
class CStrategyConfig : public MQL5_Json::IJsonSerializable { /* ... definition from previous example ... */ };

void OnStart()
{
    string config_json = /* ... (A complex JSON configuration string) ... */;
    CStrategyConfig config;
    if (MQL5_Json::JsonMapper::Deserialize(MQL5_Json::JsonParse(config_json).GetRoot(), config))
    {
        // Now you can work with the configuration as a native MQL5 object
        Print("Configuration loaded successfully into CStrategyConfig object.");
    }
}
```

#### **3.2 Stream Processing (SAX API) for Massive JSON Files**

**Example: Tallying profitable and losing trades from a huge trade log stream.**

```mql5
// 1. Define a custom event handler
class CTradeLogHandler : public MQL5_Json::IJsonStreamHandler
{ /* ... definition from previous example ... */ };

// 2. Use the stream parser
void OnStart()
{
    // huge_log_stream could be coming from a large file or network response
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

## Error Handling

**Example: Capturing and interpreting a typical JSON syntax error**

```mql5
string bad_json = "{\"symbol\": \"EURUSD\" \"price\": 1.07}"; // Missing comma
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

## Contribution

This library is developed and maintained by **ding9736**. Contributions from the community, whether in the form of issue reports or pull requests, are welcome.

* **MQL5 Profile**: [https://www.mql5.com/en/users/ding9736](https://www.mql5.com/en/users/ding9736)
* **GitHub Repository**: [https://github.com/ding9736/MQL5-JsonLib](https://github.com/ding9736/MQL5-JsonLib)

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

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
