import { Application } from "@hotwired/stimulus"
import PreventMultiSubmitController from "./prevent_multi_submit_controller"

const application = Application.start()
application.debug = false
window.Stimulus = application

// registre aqui (ou no controllers/index.js, se preferir)
application.register("prevent-multi-submit", PreventMultiSubmitController)

export { application }
