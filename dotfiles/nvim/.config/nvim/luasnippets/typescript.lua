local ls = require("luasnip")

local s = ls.snippet
local i = ls.insert_node
local t = ls.text_node
local c = ls.choice_node
local f = ls.function_node
local d = ls.dynamic_node
local sn = ls.snippet_node
local fmt = require("luasnip.extras.fmt").fmt

local extras = require("luasnip.extras")
local rep = extras.rep

local function get_component_name()
  local file_name = vim.fn.expand("%:t:r")
  if file_name == "index" then
    -- Return parent directory name if file is index
    file_name = vim.fn.expand("%:p:h:t")
  end

  return sn(nil, { i(1, file_name) })
end

local function extract_props(args)
  local text = args[1]
  local props = {}

  for _, line in ipairs(text) do
    local prop_name = line:match("^%s*([%w_]+)%??%s*:")
    if prop_name then
      table.insert(props, prop_name)
    end
  end

  local result = table.concat(props, ", ")

  return sn(nil, { i(1, result) })
end

local function get_uuid()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return string.gsub(template, "[xy]", function(ch)
    local v = (ch == "x") and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format("%x", v)
  end)
end

local function getReactStateUpdateFunctionName(args)
  local text = args[1][1]
  if text == "" then
    return ""
  end
  return "set" .. text:sub(1, 1):upper() .. text:sub(2)
end

local snippets = {
  s("prt", fmt("await new Promise(r => setTimeout(r, {}))", { i(1, "1000") })),
  s(
    "pgr",
    fmt(
      [[ 
      page.getByRole('{}', {{ name: '{}' }})
      ]],
      { i(1), i(2) }
    )
  ),
  s(
    "gbr",
    fmt(
      [[ 
      getByRole('{}', {{ name: '{}' }})
      ]],
      { i(1), i(2) }
    )
  ),
  s("iin", t("/* istanbul ignore next */")),
  s(
    "swi",
    fmt(
      [[
      switch ({var}) {{
        {case}
        /* istanbul ignore next */
        default:
          {ret}notReachable({var})
      }}
      ]],
      { var = i(1), case = i(0), ret = c(2, { t("return "), t("") }) },
      { repeat_duplicates = true }
    )
  ),
  s(
    "cas",
    fmt(
      [[
      case '{}':
        {}

      {}
      ]],
      {
        i(1),
        c(2, {
          fmt("return {}", { i(1) }),
          fmt(
            [[
            {}
              break
            ]],
            { i(1) }
          ),
          fmt(
            [[
            // TODO: will be implemented in https://revolut.atlassian.net/browse/RPOS-{}
              throw new Error('not implemented')
            ]],
            { i(1) }
          ),
        }),
        i(0),
      }
    )
  ),
  s(
    "sif",
    fmt(
      [[
        (() => {{
          {}
        }})()
      ]],
      { i(1) }
    )
  ),
  s(
    "fmc",
    fmt(
      [[
      <FormattedMessage
        id="{}"
        defaultMessage="{}"
      />
      ]],
      { i(1), i(2) }
    )
  ),
  s("fmt", fmt("formatMessage({{ id: '{}', defaultMessage: '{}' }})", { i(1), i(2) })),
  s(
    "frc",
    fmt(
      [[
      import React from 'react'

      type Props = {{
        {}
      }}

      export const {} = ({{ {} }}: Props) => {{
        {}
        return {}
      }}
      ]],
      { i(2), d(1, get_component_name), d(3, extract_props, { 2 }), i(0), i(4) }
    )
  ),
  s(
    "rcc",
    fmt(
      [[
      import React from 'react'

      type Props = {{
        {}
      }}

      export function {}({{ {} }}: Props) {{
        {}
        return {}
      }}
      ]],
      { i(2), d(1, get_component_name), d(3, extract_props, { 2 }), i(0), i(4) }
    )
  ),
  s(
    "rus",
    fmt(
      [[
      const [{}, {}] = React.useState{}({})
      {}
      ]],
      { i(1), f(getReactStateUpdateFunctionName, { 1 }), i(3), i(2), i(0) }
    )
  ),
  s(
    "tni",
    fmt(
      [[
      // TODO: will be implemented in https://revolut.atlassian.net/browse/RPOS-{}
      throw new Error("not implemented")
      ]],
      { i(1) }
    )
  ),
  s("uuid", {
    f(get_uuid),
  }),
  s("csl", fmt('console.log("{}:", {})', { rep(1), i(1) })),
  s(
    "dlc",
    fmt(
      [[
      import {{ {} }} from "~/domains/{}/useCases"
      import {{ notReachable }} from "~/toolkit"

      import {{ ErrorLayout }} from "./ErrorLayout"
      import {{ Layout }} from "./Layout"
      import {{ SkeletonLayout }} from "./SkeletonLayout"

      type Props = {{
        {}
      }}

      export function DataLoader({{ {} }}: Props) {{
        const query = {}({})
        {}
        switch (query.status) {{
          case "pending":
            return <SkeletonLayout />

          case "error":
            return <ErrorLayout />

          case "success":
            return <Layout {}={{query.data}} />

          /* istanbul ignore next */
          default:
            return notReachable(query)
        }}
      }}
      ]],
      { i(2), i(1), i(3), d(4, extract_props, { 3 }), rep(2), i(6), i(0), i(5) }
    )
  ),
}

ls.add_snippets("typescript", snippets)
ls.add_snippets("typescriptreact", snippets)
