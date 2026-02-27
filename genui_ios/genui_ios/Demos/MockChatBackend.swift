import Foundation
import A2UI

/// Mock backend that generates A2UI responses for chat demo scenarios.
///
/// Supports 6 interactive scenarios (weather, form, menu, counter, survey, booking)
/// plus a default help response.
final class MockChatBackend {

    let transport: MockTransport
    let controller: SurfaceController
    private var surfaceCounter = 0
    private var surfaceScenarios: [String: String] = [:]

    init(transport: MockTransport, controller: SurfaceController) {
        self.transport = transport
        self.controller = controller
        transport.onAction = { [weak self] event in
            self?.handleAction(event)
        }
    }

    /// Generates a response surface for the user's text. Returns the new surfaceId.
    @discardableResult
    func handleUserMessage(_ text: String) -> String {
        surfaceCounter += 1
        let sid = "chat-\(surfaceCounter)"
        let scenario = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        surfaceScenarios[sid] = scenario

        let messages = initialMessages(scenario: scenario, surfaceId: sid)
        for msg in messages {
            transport.send(msg)
        }
        return sid
    }

    // MARK: - Action Handling

    private func handleAction(_ event: UserActionEvent) {
        guard let sid = event.surfaceId,
              let scenario = surfaceScenarios[sid] else { return }

        let eventName = event.name

        switch scenario {
        case "weather":  handleWeatherAction(sid: sid, event: eventName)
        case "form":     handleFormAction(sid: sid)
        case "menu":     handleMenuAction(sid: sid, event: eventName)
        case "counter":  handleCounterAction(sid: sid, event: eventName)
        case "survey":   handleSurveyAction(sid: sid)
        case "booking":  handleBookingAction(sid: sid)
        default: break
        }
    }

    // MARK: - Initial Messages per Scenario

    private func initialMessages(scenario: String, surfaceId sid: String) -> [A2UIMessage] {
        switch scenario {
        case "weather":  return weatherInitial(sid)
        case "form":     return formInitial(sid)
        case "menu":     return menuInitial(sid)
        case "counter":  return counterInitial(sid)
        case "survey":   return surveyInitial(sid)
        case "booking":  return bookingInitial(sid)
        default:         return helpInitial(sid)
        }
    }

    // MARK: 1. Weather

    private func weatherInitial(_ sid: String) -> [A2UIMessage] {
        [
            .createSurface(CreateSurfacePayload(surfaceId: sid, catalogId: basicCatalogId)),
            .updateDataModel(UpdateDataModelPayload(surfaceId: sid, path: .root, value: [
                "city": "shanghai",
                "temp": "26°C",
                "desc": "Sunny",
            ] as JsonMap)),
            .updateComponents(UpdateComponentsPayload(surfaceId: sid, components: [
                Component(id: "root", type: "Column", properties: [
                    "children": ["title", "picker", "btn", "div", "card"]
                ]),
                Component(id: "title", type: "Text", properties: ["text": "Weather Forecast", "variant": "h4"]),
                Component(id: "picker", type: "ChoicePicker", properties: [
                    "value": ["path": "/city"] as JsonMap,
                    "label": "Select City",
                    "variant": "mutuallyExclusive",
                    "options": [
                        ["label": "Shanghai", "value": "shanghai"] as JsonMap,
                        ["label": "Beijing", "value": "beijing"] as JsonMap,
                        ["label": "Tokyo", "value": "tokyo"] as JsonMap,
                    ] as [JsonMap]
                ]),
                Component(id: "btn", type: "Button", properties: [
                    "child": "btn_t", "variant": "primary",
                    "action": ["event": ["name": "check_weather"]] as JsonMap
                ]),
                Component(id: "btn_t", type: "Text", properties: ["text": "Check Weather"]),
                Component(id: "div", type: "Divider", properties: [:]),
                Component(id: "card", type: "Card", properties: ["child": "card_col"]),
                Component(id: "card_col", type: "Column", properties: [
                    "children": ["w_icon_row", "w_temp"]
                ]),
                Component(id: "w_icon_row", type: "Row", properties: [
                    "children": ["w_icon", "w_city"], "align": "center"
                ]),
                Component(id: "w_icon", type: "Icon", properties: ["icon": "wb_sunny", "size": 28, "color": "orange"]),
                Component(id: "w_city", type: "Text", properties: [
                    "text": ["path": "/city"] as JsonMap, "variant": "h5"
                ]),
                Component(id: "w_temp", type: "Text", properties: [
                    "text": ["path": "/temp"] as JsonMap, "variant": "body"
                ]),
            ])),
        ]
    }

    private func handleWeatherAction(sid: String, event: String) {
        guard event == "check_weather" else { return }
        let model = controller.store.getDataModel(surfaceId: sid)
        let city = model.getValue(path: DataPath("/city")) as? String ?? "shanghai"

        let weatherData: (temp: String, desc: String, icon: String, color: String) = {
            switch city {
            case "beijing": return ("18°C", "Cloudy", "cloud", "gray")
            case "tokyo":   return ("22°C", "Rainy", "umbrella", "blue")
            default:        return ("26°C", "Sunny", "wb_sunny", "orange")
            }
        }()

        transport.send(.updateDataModel(UpdateDataModelPayload(
            surfaceId: sid, path: DataPath("/temp"), value: "\(weatherData.temp)  \(weatherData.desc)"
        )))
        transport.send(.updateComponents(UpdateComponentsPayload(surfaceId: sid, components: [
            Component(id: "w_icon", type: "Icon", properties: [
                "icon": weatherData.icon, "size": 28, "color": weatherData.color
            ]),
        ])))
    }

    // MARK: 2. Form

    private func formInitial(_ sid: String) -> [A2UIMessage] {
        [
            .createSurface(CreateSurfacePayload(surfaceId: sid, catalogId: basicCatalogId)),
            .updateDataModel(UpdateDataModelPayload(surfaceId: sid, path: .root, value: [
                "name": "", "email": "", "agree": false, "result": ""
            ] as JsonMap)),
            .updateComponents(UpdateComponentsPayload(surfaceId: sid, components: [
                Component(id: "root", type: "Column", properties: [
                    "children": ["title", "name_f", "email_f", "agree_f", "btn", "div", "result"]
                ]),
                Component(id: "title", type: "Text", properties: ["text": "Registration Form", "variant": "h4"]),
                Component(id: "name_f", type: "TextField", properties: [
                    "value": ["path": "/name"] as JsonMap, "label": "Full Name", "placeholder": "John Doe"
                ]),
                Component(id: "email_f", type: "TextField", properties: [
                    "value": ["path": "/email"] as JsonMap, "label": "Email", "placeholder": "john@example.com"
                ]),
                Component(id: "agree_f", type: "CheckBox", properties: [
                    "value": ["path": "/agree"] as JsonMap, "label": "I agree to the terms"
                ]),
                Component(id: "btn", type: "Button", properties: [
                    "child": "btn_t", "variant": "primary",
                    "action": ["event": ["name": "submit_form"]] as JsonMap
                ]),
                Component(id: "btn_t", type: "Text", properties: ["text": "Submit"]),
                Component(id: "div", type: "Divider", properties: [:]),
                Component(id: "result", type: "Text", properties: [
                    "text": ["path": "/result"] as JsonMap, "variant": "body"
                ]),
            ])),
        ]
    }

    private func handleFormAction(sid: String) {
        let model = controller.store.getDataModel(surfaceId: sid)
        let name = model.getValue(path: DataPath("/name")) as? String ?? ""
        let email = model.getValue(path: DataPath("/email")) as? String ?? ""
        let agree = model.getValue(path: DataPath("/agree")) as? Bool ?? false

        let result: String
        if name.trimmingCharacters(in: .whitespaces).isEmpty || email.trimmingCharacters(in: .whitespaces).isEmpty {
            result = "Please fill in all fields."
        } else if !agree {
            result = "Please agree to the terms."
        } else {
            result = "Registration successful!\nName: \(name)\nEmail: \(email)"
        }
        transport.send(.updateDataModel(UpdateDataModelPayload(
            surfaceId: sid, path: DataPath("/result"), value: result
        )))
    }

    // MARK: 3. Menu

    private func menuInitial(_ sid: String) -> [A2UIMessage] {
        [
            .createSurface(CreateSurfacePayload(surfaceId: sid, catalogId: basicCatalogId)),
            .updateDataModel(UpdateDataModelPayload(surfaceId: sid, path: .root, value: [
                "pick": "", "status": "Select a dish and order."
            ] as JsonMap)),
            .updateComponents(UpdateComponentsPayload(surfaceId: sid, components: [
                Component(id: "root", type: "Column", properties: [
                    "children": ["title", "picker", "btn", "div", "status"]
                ]),
                Component(id: "title", type: "Text", properties: ["text": "Restaurant Menu", "variant": "h4"]),
                Component(id: "picker", type: "ChoicePicker", properties: [
                    "value": ["path": "/pick"] as JsonMap,
                    "label": "Today's Specials",
                    "variant": "mutuallyExclusive",
                    "options": [
                        ["label": "Margherita Pizza  $12", "value": "pizza"] as JsonMap,
                        ["label": "Grilled Salmon    $18", "value": "salmon"] as JsonMap,
                        ["label": "Caesar Salad      $10", "value": "salad"] as JsonMap,
                        ["label": "Chocolate Cake    $8", "value": "cake"] as JsonMap,
                    ] as [JsonMap]
                ]),
                Component(id: "btn", type: "Button", properties: [
                    "child": "btn_t", "variant": "primary",
                    "action": ["event": ["name": "order"]] as JsonMap
                ]),
                Component(id: "btn_t", type: "Text", properties: ["text": "Place Order"]),
                Component(id: "div", type: "Divider", properties: [:]),
                Component(id: "status", type: "Text", properties: [
                    "text": ["path": "/status"] as JsonMap, "variant": "body"
                ]),
            ])),
        ]
    }

    private func handleMenuAction(sid: String, event: String) {
        guard event == "order" else { return }
        let model = controller.store.getDataModel(surfaceId: sid)
        let pick = model.getValue(path: DataPath("/pick")) as? String ?? ""
        let dishName: String = {
            switch pick {
            case "pizza":  return "Margherita Pizza"
            case "salmon": return "Grilled Salmon"
            case "salad":  return "Caesar Salad"
            case "cake":   return "Chocolate Cake"
            default:       return "nothing"
            }
        }()
        let msg = pick.isEmpty ? "Please select a dish first." : "Order placed: \(dishName)! Estimated time: 15 min."
        transport.send(.updateDataModel(UpdateDataModelPayload(
            surfaceId: sid, path: DataPath("/status"), value: msg
        )))
    }

    // MARK: 4. Counter

    private func counterInitial(_ sid: String) -> [A2UIMessage] {
        [
            .createSurface(CreateSurfacePayload(surfaceId: sid, catalogId: basicCatalogId)),
            .updateDataModel(UpdateDataModelPayload(surfaceId: sid, path: .root, value: [
                "count": 0
            ] as JsonMap)),
            .updateComponents(UpdateComponentsPayload(surfaceId: sid, components: [
                Component(id: "root", type: "Column", properties: [
                    "children": ["title", "display", "row"]
                ]),
                Component(id: "title", type: "Text", properties: ["text": "Counter", "variant": "h4"]),
                Component(id: "display", type: "Text", properties: [
                    "text": ["path": "/count"] as JsonMap, "variant": "h2"
                ]),
                Component(id: "row", type: "Row", properties: [
                    "children": ["dec_btn", "inc_btn"], "justify": "center"
                ]),
                Component(id: "dec_btn", type: "Button", properties: [
                    "child": "dec_t", "variant": "primary",
                    "action": ["event": ["name": "decrement"]] as JsonMap
                ]),
                Component(id: "dec_t", type: "Text", properties: ["text": "  -  "]),
                Component(id: "inc_btn", type: "Button", properties: [
                    "child": "inc_t", "variant": "primary",
                    "action": ["event": ["name": "increment"]] as JsonMap
                ]),
                Component(id: "inc_t", type: "Text", properties: ["text": "  +  "]),
            ])),
        ]
    }

    private func handleCounterAction(sid: String, event: String) {
        let model = controller.store.getDataModel(surfaceId: sid)
        let current = (model.getValue(path: DataPath("/count")) as? NSNumber)?.intValue ?? 0
        let newValue: Int
        switch event {
        case "increment": newValue = current + 1
        case "decrement": newValue = current - 1
        default: return
        }
        transport.send(.updateDataModel(UpdateDataModelPayload(
            surfaceId: sid, path: DataPath("/count"), value: newValue
        )))
    }

    // MARK: 5. Survey

    private func surveyInitial(_ sid: String) -> [A2UIMessage] {
        [
            .createSurface(CreateSurfacePayload(surfaceId: sid, catalogId: basicCatalogId)),
            .updateDataModel(UpdateDataModelPayload(surfaceId: sid, path: .root, value: [
                "rating": 5, "frequency": "daily", "feedback": "", "result": ""
            ] as JsonMap)),
            .updateComponents(UpdateComponentsPayload(surfaceId: sid, components: [
                Component(id: "root", type: "Column", properties: [
                    "children": ["title", "slider", "freq", "fb", "btn", "div", "result"]
                ]),
                Component(id: "title", type: "Text", properties: ["text": "Satisfaction Survey", "variant": "h4"]),
                Component(id: "slider", type: "Slider", properties: [
                    "value": ["path": "/rating"] as JsonMap,
                    "min": 1, "max": 10, "label": "Rating (1-10)"
                ]),
                Component(id: "freq", type: "ChoicePicker", properties: [
                    "value": ["path": "/frequency"] as JsonMap,
                    "label": "How often do you use this?",
                    "variant": "mutuallyExclusive",
                    "options": [
                        ["label": "Daily", "value": "daily"] as JsonMap,
                        ["label": "Weekly", "value": "weekly"] as JsonMap,
                        ["label": "Monthly", "value": "monthly"] as JsonMap,
                    ] as [JsonMap]
                ]),
                Component(id: "fb", type: "TextField", properties: [
                    "value": ["path": "/feedback"] as JsonMap,
                    "label": "Feedback", "placeholder": "Any suggestions?"
                ]),
                Component(id: "btn", type: "Button", properties: [
                    "child": "btn_t", "variant": "primary",
                    "action": ["event": ["name": "submit_survey"]] as JsonMap
                ]),
                Component(id: "btn_t", type: "Text", properties: ["text": "Submit Survey"]),
                Component(id: "div", type: "Divider", properties: [:]),
                Component(id: "result", type: "Text", properties: [
                    "text": ["path": "/result"] as JsonMap, "variant": "body"
                ]),
            ])),
        ]
    }

    private func handleSurveyAction(sid: String) {
        let model = controller.store.getDataModel(surfaceId: sid)
        let rating = (model.getValue(path: DataPath("/rating")) as? NSNumber)?.intValue ?? 5
        let freq = model.getValue(path: DataPath("/frequency")) as? String ?? "daily"
        let feedback = model.getValue(path: DataPath("/feedback")) as? String ?? ""

        var result = "Thank you for your feedback!\n"
        result += "Rating: \(rating)/10\n"
        result += "Usage: \(freq)\n"
        if !feedback.trimmingCharacters(in: .whitespaces).isEmpty {
            result += "Comment: \(feedback)"
        }
        transport.send(.updateDataModel(UpdateDataModelPayload(
            surfaceId: sid, path: DataPath("/result"), value: result
        )))
    }

    // MARK: 6. Booking

    private func bookingInitial(_ sid: String) -> [A2UIMessage] {
        [
            .createSurface(CreateSurfacePayload(surfaceId: sid, catalogId: basicCatalogId)),
            .updateDataModel(UpdateDataModelPayload(surfaceId: sid, path: .root, value: [
                "date": "", "timeslot": "morning", "notes": "", "result": ""
            ] as JsonMap)),
            .updateComponents(UpdateComponentsPayload(surfaceId: sid, components: [
                Component(id: "root", type: "Column", properties: [
                    "children": ["title", "dt", "slot", "notes", "btn", "div", "result"]
                ]),
                Component(id: "title", type: "Text", properties: ["text": "Reservation", "variant": "h4"]),
                Component(id: "dt", type: "DateTimeInput", properties: [
                    "value": ["path": "/date"] as JsonMap, "label": "Date", "variant": "date"
                ]),
                Component(id: "slot", type: "ChoicePicker", properties: [
                    "value": ["path": "/timeslot"] as JsonMap,
                    "label": "Time Slot",
                    "variant": "mutuallyExclusive",
                    "options": [
                        ["label": "Morning (9-12)", "value": "morning"] as JsonMap,
                        ["label": "Afternoon (13-17)", "value": "afternoon"] as JsonMap,
                        ["label": "Evening (18-21)", "value": "evening"] as JsonMap,
                    ] as [JsonMap]
                ]),
                Component(id: "notes", type: "TextField", properties: [
                    "value": ["path": "/notes"] as JsonMap,
                    "label": "Notes", "placeholder": "Special requests..."
                ]),
                Component(id: "btn", type: "Button", properties: [
                    "child": "btn_t", "variant": "primary",
                    "action": ["event": ["name": "confirm_booking"]] as JsonMap
                ]),
                Component(id: "btn_t", type: "Text", properties: ["text": "Confirm Booking"]),
                Component(id: "div", type: "Divider", properties: [:]),
                Component(id: "result", type: "Text", properties: [
                    "text": ["path": "/result"] as JsonMap, "variant": "body"
                ]),
            ])),
        ]
    }

    private func handleBookingAction(sid: String) {
        let model = controller.store.getDataModel(surfaceId: sid)
        let date = model.getValue(path: DataPath("/date")) as? String ?? ""
        let slot = model.getValue(path: DataPath("/timeslot")) as? String ?? "morning"
        let notes = model.getValue(path: DataPath("/notes")) as? String ?? ""

        if date.trimmingCharacters(in: .whitespaces).isEmpty {
            transport.send(.updateDataModel(UpdateDataModelPayload(
                surfaceId: sid, path: DataPath("/result"), value: "Please select a date."
            )))
            return
        }

        let slotLabel: String = {
            switch slot {
            case "afternoon": return "Afternoon (13-17)"
            case "evening":   return "Evening (18-21)"
            default:          return "Morning (9-12)"
            }
        }()

        var result = "Booking confirmed!\n"
        result += "Date: \(date)\n"
        result += "Time: \(slotLabel)\n"
        if !notes.trimmingCharacters(in: .whitespaces).isEmpty {
            result += "Notes: \(notes)"
        }
        transport.send(.updateDataModel(UpdateDataModelPayload(
            surfaceId: sid, path: DataPath("/result"), value: result
        )))
    }

    // MARK: 7. Default / Help

    private func helpInitial(_ sid: String) -> [A2UIMessage] {
        [
            .createSurface(CreateSurfacePayload(surfaceId: sid, catalogId: basicCatalogId)),
            .updateComponents(UpdateComponentsPayload(surfaceId: sid, components: [
                Component(id: "root", type: "Column", properties: [
                    "children": ["title", "desc", "div", "cmds"]
                ]),
                Component(id: "title", type: "Text", properties: [
                    "text": "A2UI Chat Demo", "variant": "h4"
                ]),
                Component(id: "desc", type: "Text", properties: [
                    "text": "Try one of these commands to see interactive A2UI components:", "variant": "body"
                ]),
                Component(id: "div", type: "Divider", properties: [:]),
                Component(id: "cmds", type: "Text", properties: [
                    "text": "**weather** - Weather forecast with city selector\n**form** - Registration form with validation\n**menu** - Restaurant ordering\n**counter** - Interactive counter\n**survey** - Satisfaction survey\n**booking** - Date/time reservation",
                    "variant": "body"
                ]),
            ])),
        ]
    }
}
