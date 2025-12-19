# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "controllers/reports_controller", to: "controllers/reports_controller.js"
pin "reports/app", to: "reports/app.js"

pin "react", to: "https://ga.jspm.io/npm:react@18.3.1/index.js", preload: true
pin "react-dom", to: "https://ga.jspm.io/npm:react-dom@18.3.1/index.js", preload: true
pin "react-dom/client", to: "https://ga.jspm.io/npm:react-dom@18.3.1/client.js", preload: true
pin "loose-envify", to: "https://ga.jspm.io/npm:loose-envify@1.4.0/index.js"
pin "stream", to: "https://ga.jspm.io/npm:stream@0.0.2/index.js"
pin "util", to: "https://ga.jspm.io/npm:util@0.12.5/util.js"
pin "inherits", to: "https://ga.jspm.io/npm:inherits@2.0.4/inherits_browser.js"
pin "scheduler", to: "https://ga.jspm.io/npm:scheduler@0.23.2/index.js"
pin "scheduler/tracing", to: "scheduler-tracing-shim.js"
pin "chart.js", to: "https://ga.jspm.io/npm:chart.js@4.4.5/dist/chart.js"
pin "chart.js/auto", to: "https://ga.jspm.io/npm:chart.js@4.4.5/auto/auto.js"
pin "@kurkle/color", to: "https://ga.jspm.io/npm:@kurkle/color@0.3.2/dist/color.esm.js"

# Drag-and-drop sorting (admin survey builder)
pin "sortablejs", to: "https://ga.jspm.io/npm:sortablejs@1.15.6/modular/sortable.esm.js"
