// Unified Whitelabel JSON Tool (React 18, no build step)
(function () {
  const { useState, useMemo } = React;
  const e = React.createElement;

  function buildConfig(state) {
    const borderRadius = state.roundedBorder ? "9999px" : "4px";
    const gradient = `linear-gradient(180deg, ${state.brandPrimaryColor} 0%, ${state.brandPrimaryColor} 100%)`;

    return {
      common: {
        logo: state.merchantLogo,
        header: {
          background: state.headerBackground,
        },
        secure_txn: state.secureTxnColor,
        footer: {
          hyper_link: state.legalLink,
          term_and_condition_link: state.legalLink,
          privacy_and_policy_link: state.legalLink,
        },
      },
      checkout: {
        background: state.pageBackground,
        button_continue: {
          background: state.brandPrimaryColor,
          border_radius: borderRadius,
        },
        summary_box: {
          background: state.summaryBoxColor,
        },
      },
      commonV2: {
        logo: state.merchantLogo,
        header: {
          background: state.headerBackground,
        },
        secure_txn: state.secureTxnColor,
        background: state.pageBackground,
        bottom_sheet: {
          background: state.summaryBoxColor,
        },
        footer: {
          hyper_link: state.legalLink,
          term_and_condition_link: state.legalLink,
          privacy_and_policy_link: state.legalLink,
        },
      },
      checkoutV2: {
        button_continue: {
          background: gradient,
          border_radius: borderRadius,
        },
      },
    };
  }

  function WhitelabelJsonTool() {
    const [state, setState] = useState({
      merchantLogo: "",
      headerBackground: "#0f172a",
      secureTxnColor: "#22c55e",
      brandPrimaryColor: "#2563eb",
      pageBackground: "#020617",
      summaryBoxColor: "#0b1120",
      legalLink: "",
      roundedBorder: true,
    });

    const [copied, setCopied] = useState(false);

    const jsonString = useMemo(
      () => JSON.stringify(buildConfig(state), null, 2),
      [state]
    );

    function updateField(key, value) {
      setState(function (prev) {
        return Object.assign({}, prev, { [key]: value });
      });
      setCopied(false);
    }

    function handleCopy() {
      if (navigator && navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard
          .writeText(jsonString)
          .then(function () {
            setCopied(true);
            setTimeout(function () {
              setCopied(false);
            }, 1400);
          })
          .catch(function () {
            fallbackCopy(jsonString);
          });
      } else {
        fallbackCopy(jsonString);
      }
    }

    function fallbackCopy(text) {
      try {
        var textarea = document.createElement("textarea");
        textarea.value = text;
        textarea.style.position = "fixed";
        textarea.style.opacity = "0";
        document.body.appendChild(textarea);
        textarea.focus();
        textarea.select();
        document.execCommand("copy");
        document.body.removeChild(textarea);
        setCopied(true);
        setTimeout(function () {
          setCopied(false);
        }, 1400);
      } catch (e) {
        console.error("Copy failed", e);
      }
    }

    return e(
      "div",
      { className: "app-shell" },
      // Sidebar / Inputs
      e(
        "aside",
        { className: "sidebar" },
        e(
          "div",
          { className: "sidebar-header" },
          e(
            "div",
            { className: "sidebar-title" },
            "Unified Whitelabel JSON"
          ),
          e(
            "div",
            { className: "sidebar-subtitle" },
            "Enter each value once. This tool syncs V1 and V2 JSON automatically."
          ),
          e(
            "div",
            { className: "badge" },
            e("span", { className: "badge-dot" }),
            e("span", null, "V1 + V2 in sync")
          )
        ),

        // Header section
        e(
          "section",
          { className: "section" },
          e("div", { className: "section-title" }, "Header"),

          // Merchant Logo
          e(
            "div",
            { className: "field" },
            e(
              "label",
              { className: "field-label" },
              e("span", null, "Merchant Logo URL"),
              e("span", { className: "field-hint" }, "Maps to logo (V1 + V2)")
            ),
            e("input", {
              type: "url",
              placeholder: "https://cdn.payout.com/merchant-logo.png",
              value: state.merchantLogo,
              onChange: function (evt) {
                updateField("merchantLogo", evt.target.value);
              },
            })
          ),

          // Header background color
          e(
            "div",
            { className: "field" },
            e(
              "label",
              { className: "field-label" },
              e("span", null, "Header Background"),
              e(
                "span",
                { className: "field-hint" },
                "common.header.background & commonV2.header.background"
              )
            ),
            e(
              "div",
              { className: "color-row" },
              e("input", {
                type: "color",
                value: state.headerBackground,
                onChange: function (evt) {
                  updateField("headerBackground", evt.target.value);
                },
              }),
              e("input", {
                type: "text",
                value: state.headerBackground,
                onChange: function (evt) {
                  updateField("headerBackground", evt.target.value);
                },
              })
            )
          ),

          // Secure Txn color
          e(
            "div",
            { className: "field" },
            e(
              "label",
              { className: "field-label" },
              e("span", null, "Secure Transaction Color"),
              e(
                "span",
                { className: "field-hint" },
                "common.secure_txn & commonV2.secure_txn"
              )
            ),
            e(
              "div",
              { className: "color-row" },
              e("input", {
                type: "color",
                value: state.secureTxnColor,
                onChange: function (evt) {
                  updateField("secureTxnColor", evt.target.value);
                },
              }),
              e("input", {
                type: "text",
                value: state.secureTxnColor,
                onChange: function (evt) {
                  updateField("secureTxnColor", evt.target.value);
                },
              })
            )
          )
        ),

        // Buttons section
        e(
          "section",
          { className: "section" },
          e("div", { className: "section-title" }, "Buttons"),

          // Brand primary color
          e(
            "div",
            { className: "field" },
            e(
              "label",
              { className: "field-label" },
              e("span", null, "Brand Primary (Button)"),
              e(
                "span",
                { className: "field-hint" },
                "checkout.button_continue.background & gradient in checkoutV2"
              )
            ),
            e(
              "div",
              { className: "color-row" },
              e("input", {
                type: "color",
                value: state.brandPrimaryColor,
                onChange: function (evt) {
                  updateField("brandPrimaryColor", evt.target.value);
                },
              }),
              e("input", {
                type: "text",
                value: state.brandPrimaryColor,
                onChange: function (evt) {
                  updateField("brandPrimaryColor", evt.target.value);
                },
              })
            )
          ),

          // Border radius toggle
          e(
            "div",
            { className: "field" },
            e(
              "label",
              { className: "field-label" },
              e("span", null, "Border Radius"),
              e(
                "span",
                { className: "field-hint" },
                "Applies to button_continue (V1 + V2)"
              )
            ),
            e(
              "label",
              {
                className: "toggle",
                onClick: function () {
                  updateField("roundedBorder", !state.roundedBorder);
                },
              },
              e(
                "div",
                {
                  className:
                    "toggle-track" + (state.roundedBorder ? " on" : ""),
                },
                e("div", { className: "toggle-thumb" })
              ),
              e(
                "div",
                { className: "toggle-label" },
                state.roundedBorder
                  ? e(
                      React.Fragment,
                      null,
                      "Rounded ",
                      e("span", null, "(9999px)")
                    )
                  : e(
                      React.Fragment,
                      null,
                      "Standard ",
                      e("span", null, "(4px)")
                    )
              )
            )
          )
        ),

        // Layout section
        e(
          "section",
          { className: "section" },
          e("div", { className: "section-title" }, "Layout & Surfaces"),

          // Page background
          e(
            "div",
            { className: "field" },
            e(
              "label",
              { className: "field-label" },
              e("span", null, "Page Background"),
              e(
                "span",
                { className: "field-hint" },
                "checkout.background (V1) & commonV2.background"
              )
            ),
            e(
              "div",
              { className: "color-row" },
              e("input", {
                type: "color",
                value: state.pageBackground,
                onChange: function (evt) {
                  updateField("pageBackground", evt.target.value);
                },
              }),
              e("input", {
                type: "text",
                value: state.pageBackground,
                onChange: function (evt) {
                  updateField("pageBackground", evt.target.value);
                },
              })
            )
          ),

          // Summary box color
          e(
            "div",
            { className: "field" },
            e(
              "label",
              { className: "field-label" },
              e("span", null, "Summary Box Background"),
              e(
                "span",
                { className: "field-hint" },
                "summary_box.background (V1) & commonV2.bottom_sheet.background"
              )
            ),
            e(
              "div",
              { className: "color-row" },
              e("input", {
                type: "color",
                value: state.summaryBoxColor,
                onChange: function (evt) {
                  updateField("summaryBoxColor", evt.target.value);
                },
              }),
              e("input", {
                type: "text",
                value: state.summaryBoxColor,
                onChange: function (evt) {
                  updateField("summaryBoxColor", evt.target.value);
                },
              })
            )
          )
        ),

        // Links section
        e(
          "section",
          { className: "section" },
          e("div", { className: "section-title" }, "Links"),
          e(
            "div",
            { className: "field" },
            e(
              "label",
              { className: "field-label" },
              e("span", null, "Legal Links URL"),
              e(
                "span",
                { className: "field-hint" },
                "hyper_link, term_and_condition_link, privacy_and_policy_link (V1 + V2)"
              )
            ),
            e("input", {
              type: "url",
              placeholder: "https://payout.com/legal",
              value: state.legalLink,
              onChange: function (evt) {
                updateField("legalLink", evt.target.value);
              },
            })
          )
        )
      ),

      // Main / JSON
      e(
        "main",
        { className: "main" },
        e(
          "div",
          { className: "main-header" },
          e(
            "div",
            null,
            e(
              "div",
              { className: "main-title" },
              "Whitelabel JSON Generator"
            ),
            e(
              "div",
              { style: { marginTop: 4, fontSize: 12, color: "#9ca3af" } },
              "Live, unified config for ",
              e("strong", null, "common, checkout, commonV2, checkoutV2")
            )
          ),
          e(
            "div",
            { className: "pill" },
            "Single source of truth"
          )
        ),
        e(
          "div",
          { className: "json-shell" },
          e(
            "div",
            { className: "json-toolbar" },
            e(
              "div",
              { className: "json-toolbar-left" },
              e("span", { className: "json-dot" }),
              e("span", null, "Unified Output"),
              e(
                "span",
                { className: "pill-small" },
                e("span", { className: "pill-small-dot" }),
                "V1 + V2"
              )
            ),
            e(
              "button",
              { type: "button", className: "copy-btn", onClick: handleCopy },
              e(
                "span",
                {
                  style: {
                    display: "inline-block",
                    width: 10,
                    height: 10,
                    borderRadius: 2,
                    border: "1px solid rgba(148, 163, 184, 0.9)",
                    position: "relative",
                  },
                },
                e("span", {
                  style: {
                    position: "absolute",
                    top: 2,
                    left: 3,
                    width: 5,
                    height: 3,
                    borderLeft: "1px solid rgba(148, 163, 184, 0.9)",
                    borderBottom: "1px solid rgba(148, 163, 184, 0.9)",
                    transform: "rotate(-45deg)",
                  },
                })
              ),
              e(
                "span",
                null,
                copied ? "Copied" : "Copy JSON"
              )
            )
          ),
          e(
            "div",
            { className: "json-output" },
            e("pre", null, jsonString)
          )
        )
      )
    );
  }

  var rootElement = document.getElementById("root");
  if (rootElement) {
    var root = ReactDOM.createRoot(rootElement);
    root.render(e(WhitelabelJsonTool));
  }
})();

