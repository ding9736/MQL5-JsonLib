//+------------------------------------------------------------------+
//| Core/JsonQuery.mqh                                               |
//+------------------------------------------------------------------+
#ifndef MQL5_JSON_QUERY
#define MQL5_JSON_QUERY

#include "JsonDocument.mqh"
#include "JsonPath.mqh"

namespace MQL5_Json
{
void JsonMergeHelper(JsonNode &target, const JsonNode &patch)
{
   if (!patch.IsObject() || !target.IsObject()) return;
   string keys[];
   patch.GetKeys(keys);
   for (int i=0; i < ArraySize(keys); i++)
   {
      string key = keys[i];
      JsonNode patch_value = patch.Get(key);
      if(!patch_value.IsValid()) continue;
      JsonNode target_node = target.Get(key);
      if(patch_value.IsObject() && target_node.IsValid() && target_node.IsObject())
      {
         JsonMergeHelper(target_node, patch_value);
      }
      else
      {
         target.Set(key, patch_value);
      }
   }
}


namespace JsonQuery
{
int SelectNodes(const JsonNode &start_node, const string &path, JsonNode &out_nodes[], JsonError &error, ENUM_JSONPATH_MODE mode = MODE_SIMPLE)
{
   ArrayFree(out_nodes);
   if(!start_node.IsValid())
   {
      error.message="Cannot select nodes from an invalid start node.";
      return 0;
   }
   switch(mode)
   {
   case MODE_SIMPLE:
   case MODE_ADVANCED:
   {
      Internal::CJsonPathEvaluatorAdvanced evaluator;
      return evaluator.Evaluate(out_nodes, start_node, path, error);
   }
   }
   return 0;
}

JsonNode SelectSingleNode(const JsonNode &start_node, const string &path, JsonError &error, ENUM_JSONPATH_MODE mode = MODE_SIMPLE)
{
   JsonNode results[];
   if(SelectNodes(start_node, path, results, error, mode) > 0) return results[0];
   return JsonNode();
}

JsonNode Query(const JsonNode &start_node, const string &path, ENUM_JSONPATH_MODE mode = MODE_SIMPLE)
{
   JsonError error;
   return SelectSingleNode(start_node, path, error, mode);
}

JsonDocument Merge(const JsonDocument &target_doc, const JsonDocument &patch_doc)
{
   if(!target_doc.IsValid()) return JsonDocument();
   if(!patch_doc.IsValid() || !patch_doc.GetRoot().IsObject()) return target_doc.Clone();
   JsonDocument result = target_doc.Clone();
   JsonMergeHelper(result.GetRoot(), patch_doc.GetRoot());
   return result;
}

}
}

#endif // MQL5_JSON_QUERY


