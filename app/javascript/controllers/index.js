// Import and register all your controllers from the importmap under controllers/*

import { application } from "controllers/application"

// Eager load all controllers defined in the import map under controllers/**/*_controller
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
console.log("[stimulus] index loaded")

// Explicit registration as well, so the Munsell picker works even if eager
// loading doesn't pick it up in this app's importmap setup. Re-registering the
// same identifier is harmless.
import MunsellPickerController from "controllers/munsell_picker_controller"
application.register("munsell-picker", MunsellPickerController)

import RepeatableController from "controllers/repeatable_controller"
application.register("repeatable", RepeatableController)

import AnnotationOverlayController from "controllers/annotation_overlay_controller"
application.register("annotation-overlay", AnnotationOverlayController)

// Lazy load controllers as they appear in the DOM (remember not to preload controllers in import map!)
// import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
// lazyLoadControllersFrom("controllers", application)
