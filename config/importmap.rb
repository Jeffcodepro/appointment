# config/importmap.rb

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true

pin "controllers", to: "controllers/index.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# ✅ Corrigir 404 do Active Storage (usar arquivo remoto oficial)
pin "@rails/activestorage", to: "https://ga.jspm.io/npm:@rails/activestorage@7.1.3-4/app/assets/javascripts/activestorage.esm.js"

# (restante do seu arquivo)
pin "bootstrap", to: "bootstrap.min.js", preload: true
pin "@popperjs/core", to: "popper.js", preload: true
pin "mapbox-gl", to: "https://ga.jspm.io/npm:mapbox-gl@3.1.2/dist/mapbox-gl.js"
pin "process", to: "https://ga.jspm.io/npm:@jspm/core@2.1.0/nodelibs/browser/process-production.js"
