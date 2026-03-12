import UIKit
import A2UI

/// Demo: 复合组件 (Molecules) 与 容器组件 (Organisms)
///
/// 按照 Excel 表格中的组件列表，展示由原子组件组合而成的复合组件和容器组件。
/// 这些组件均可通过 Column、Row、Card、Text、Button、Image 等原子组件组合实现。
class MoleculesAndOrganismsDemoVC: UIViewController {

    private var controller: SurfaceController!

    private struct Section {
        let name: String
        let category: String
        let categoryColor: UIColor
        let surfaceId: String
        let components: [Component]
        let dataModel: JsonMap?
        let fixedHeight: CGFloat?

        init(name: String, category: String, categoryColor: UIColor, surfaceId: String,
             components: [Component], dataModel: JsonMap? = nil, fixedHeight: CGFloat? = nil) {
            self.name = name
            self.category = category
            self.categoryColor = categoryColor
            self.surfaceId = surfaceId
            self.components = components
            self.dataModel = dataModel
            self.fixedHeight = fixedHeight
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        let catalog = BasicCatalog.create()
        controller = SurfaceController(catalogs: [catalog])

        let sections = Self.buildAllSections()

        for s in sections {
            controller.handleMessage(.createSurface(CreateSurfacePayload(
                surfaceId: s.surfaceId, catalogId: basicCatalogId
            )))
            if let dm = s.dataModel {
                controller.handleMessage(.updateDataModel(UpdateDataModelPayload(
                    surfaceId: s.surfaceId, path: .root, value: dm
                )))
            }
            controller.handleMessage(.updateComponents(UpdateComponentsPayload(
                surfaceId: s.surfaceId, components: s.components
            )))
        }

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        scrollView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
        ])

        var lastCategory = ""
        for s in sections {
            if s.category != lastCategory {
                lastCategory = s.category
                stack.addArrangedSubview(makeCategoryHeader(s.category))
            }
            stack.addArrangedSubview(makeCard(s))
        }
    }

    // MARK: - UI Builders

    private func makeCategoryHeader(_ title: String) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .label
        let wrapper = UIView()
        wrapper.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
        ])
        return wrapper
    }

    private func makeCard(_ section: Section) -> UIView {
        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 12
        card.clipsToBounds = true

        let vStack = UIStackView()
        vStack.axis = .vertical
        vStack.spacing = 0
        card.addSubview(vStack)
        vStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: card.topAnchor),
            vStack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            vStack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            vStack.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])

        let headerContainer = UIView()
        let headerStack = UIStackView()
        headerStack.axis = .horizontal
        headerStack.spacing = 8
        headerStack.alignment = .center
        headerContainer.addSubview(headerStack)
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 12),
            headerStack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            headerStack.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -8),
        ])

        let badge = BadgeLabel()
        badge.text = section.category
        badge.font = .systemFont(ofSize: 11, weight: .semibold)
        badge.textColor = .white
        badge.backgroundColor = section.categoryColor
        badge.layer.cornerRadius = 4
        badge.clipsToBounds = true
        badge.padding = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)
        badge.setContentHuggingPriority(.required, for: .horizontal)
        headerStack.addArrangedSubview(badge)

        let nameLabel = UILabel()
        nameLabel.text = section.name
        nameLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        headerStack.addArrangedSubview(nameLabel)

        vStack.addArrangedSubview(headerContainer)

        let previewContainer = UIView()
        previewContainer.backgroundColor = .systemBackground
        let surfaceView = SurfaceView(surfaceContext: controller.contextFor(surfaceId: section.surfaceId))
        previewContainer.addSubview(surfaceView)
        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            surfaceView.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 12),
            surfaceView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 16),
            surfaceView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -16),
            surfaceView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -12),
        ])
        if let h = section.fixedHeight {
            previewContainer.heightAnchor.constraint(equalToConstant: h).isActive = true
            previewContainer.clipsToBounds = true
        }
        vStack.addArrangedSubview(previewContainer)

        return card
    }

    // MARK: - Section Definitions

    private static let molecules = UIColor.systemTeal
    private static let organisms = UIColor.systemIndigo

    private static func buildAllSections() -> [Section] {
        [
            // 复合组件 (Molecules)
            ratingSection(),
            filterTagsSection(),
            photoInputSection(),
            linearProgressSection(),
            circularProgressSection(),
            tabsSection(),
            selectionListSection(),
            orderedDisplayListSection(),
            tagTextSection(),
            selectionWrapSection(),
            dropdownSection(),
            // 容器组件 (Organisms)
            dateTimePickerSection(),
            selectionGridSection(),
            orderedSelectionListSection(),
            rollPickerSection(),
            rollPickerCardSection(),
            carouselSection(),
            tickSliderSection(),
            passwordKeypadSection(),
        ]
    }

    // MARK: - 复合组件 (Molecules)

    private static func ratingSection() -> Section {
        Section(name: "星级评分条 (Rating Bar)", category: "复合组件", categoryColor: molecules,
                surfaceId: "mo-rating", components: [
                Component(id: "root", type: "Column", properties: ["children": ["rating", "desc"]]),
                Component(id: "rating", type: "Rating", properties: [
                    "rating": ["path": "/rating"] as JsonMap,
                    "text": "4.2 分"
                ]),
                Component(id: "desc", type: "Text", properties: [
                    "text": "餐厅、商品评分展示",
                    "variant": "caption"
                ]),
            ], dataModel: ["rating": 4.2])
    }

    private static func filterTagsSection() -> Section {
        Section(name: "筛选标签组", category: "复合组件", categoryColor: molecules,
                surfaceId: "mo-filtertags", components: [
                Component(id: "root", type: "Column", properties: ["children": ["tags", "desc"]]),
                Component(id: "tags", type: "FilterTags", properties: [
                    "tags": ["川菜", "人均 ¥80", "营业中", "距离 500m"]
                ]),
                Component(id: "desc", type: "Text", properties: [
                    "text": "并列展示属性标签，仅展示不交互",
                    "variant": "caption"
                ]),
            ])
    }

    private static func photoInputSection() -> Section {
        Section(name: "上传图片 (PhotoInput)", category: "复合组件", categoryColor: molecules,
                surfaceId: "mo-photo", components: [
                Component(id: "root", type: "Column", properties: ["children": ["pi", "desc"]]),
                Component(id: "pi", type: "PhotoInput", properties: [
                    "value": ["path": "/photoUrl"] as JsonMap,
                    "hasValue": ["path": "/hasPhoto"] as JsonMap,
                    "placeholder": "Snap a pic"
                ]),
                Component(id: "desc", type: "Text", properties: [
                    "text": "点击拍照或从相册选择，模拟上传",
                    "variant": "caption"
                ]),
            ], dataModel: ["photoUrl": "", "hasPhoto": false])
    }

    private static func linearProgressSection() -> Section {
        Section(name: "进度条组件", category: "复合组件", categoryColor: molecules,
                surfaceId: "mo-linear", components: [
                Component(id: "root", type: "Column", properties: ["children": ["lp", "desc"]]),
                Component(id: "lp", type: "LinearProgress", properties: [
                    "progress": ["path": "/progress"] as JsonMap
                ]),
                Component(id: "desc", type: "Text", properties: [
                    "text": "卡路里消耗 75%",
                    "variant": "caption"
                ]),
            ], dataModel: ["progress": 0.75])
    }

    private static func circularProgressSection() -> Section {
        Section(name: "圆环进度组件", category: "复合组件", categoryColor: molecules,
                surfaceId: "mo-circular", components: [
                Component(id: "root", type: "Column", properties: ["children": ["cp", "desc"]]),
                Component(id: "cp", type: "CircularProgress", properties: [
                    "value": ["path": "/value"] as JsonMap,
                    "max": ["path": "/max"] as JsonMap,
                    "style": "positive"
                ]),
                Component(id: "desc", type: "Text", properties: [
                    "text": "健康评分 85/100",
                    "variant": "caption"
                ]),
            ], dataModel: ["value": 85, "max": 100])
    }

    private static func tabsSection() -> Section {
        Section(name: "Tab 切换", category: "复合组件", categoryColor: molecules,
                surfaceId: "mo-tabs", components: [
                Component(id: "root", type: "Tabs", properties: [
                    "tabs": [
                        ["label": "营养", "content": "tab1"] as JsonMap,
                        ["label": "热量", "content": "tab2"] as JsonMap,
                        ["label": "成分", "content": "tab3"] as JsonMap,
                    ] as [JsonMap]
                ]),
                Component(id: "tab1", type: "Text", properties: ["text": "营养标签内容", "variant": "body"]),
                Component(id: "tab2", type: "Text", properties: ["text": "热量信息", "variant": "body"]),
                Component(id: "tab3", type: "Text", properties: ["text": "成分说明", "variant": "body"]),
            ])
    }

    private static func selectionListSection() -> Section {
        Section(name: "选项多选/单选", category: "复合组件", categoryColor: molecules,
                surfaceId: "mo-sel-list", components: [
                Component(id: "root", type: "Column", properties: ["children": ["sl", "desc"]]),
                Component(id: "sl", type: "SelectionList", properties: [
                    "items": [
                        ["value": "a", "child": "opt_a"] as [String: Any],
                        ["value": "b", "child": "opt_b"] as [String: Any],
                        ["value": "c", "child": "opt_c"] as [String: Any],
                    ] as [JsonMap],
                    "selection": ["path": "/sel"] as JsonMap,
                    "maxSelection": 2,
                    "requiredSelection": 1
                ]),
                Component(id: "opt_a", type: "Text", properties: ["text": "选项 A", "variant": "body"]),
                Component(id: "opt_b", type: "Text", properties: ["text": "选项 B", "variant": "body"]),
                Component(id: "opt_c", type: "Text", properties: ["text": "选项 C", "variant": "body"]),
                Component(id: "desc", type: "Text", properties: [
                    "text": "带勾选控件的列表，支持单选/多选",
                    "variant": "caption"
                ]),
            ], dataModel: ["sel": ["a"]])
    }

    private static func orderedDisplayListSection() -> Section {
        Section(name: "带数字的展示列表", category: "复合组件", categoryColor: molecules,
                surfaceId: "mo-ordered", components: [
                Component(id: "root", type: "Column", properties: ["children": ["odl", "desc"]]),
                Component(id: "odl", type: "OrderedDisplayList", properties: [
                    "items": [
                        ["child": "step1"] as [String: Any],
                        ["child": "step2"] as [String: Any],
                        ["child": "step3"] as [String: Any],
                    ] as [JsonMap]
                ]),
                Component(id: "step1", type: "Text", properties: ["text": "准备食材", "variant": "body"]),
                Component(id: "step2", type: "Text", properties: ["text": "加热烹饪", "variant": "body"]),
                Component(id: "step3", type: "Text", properties: ["text": "装盘上桌", "variant": "body"]),
                Component(id: "desc", type: "Text", properties: [
                    "text": "强调先后顺序的步骤列表",
                    "variant": "caption"
                ]),
            ])
    }

    private static func tagTextSection() -> Section {
        Section(name: "详情标签组 (Tag Group)", category: "复合组件", categoryColor: molecules,
                surfaceId: "mo-tagtext", components: [
                Component(id: "root", type: "Column", properties: ["children": ["tt", "desc"]]),
                Component(id: "tt", type: "TagText", properties: [
                    "segments": ["literalArray": [
                        ["text": "川菜", "style": "default"] as [String: Any],
                        ["text": "人均 ¥80", "style": "secondary"] as [String: Any],
                        ["text": "推荐", "style": "highlight"] as [String: Any],
                    ]] as [String: Any]
                ]),
                Component(id: "desc", type: "Text", properties: [
                    "text": "并列展示属性、特征、状态标签",
                    "variant": "caption"
                ]),
            ])
    }

    private static func selectionWrapSection() -> Section {
        Section(name: "选择标签 (Selection Tag)", category: "复合组件", categoryColor: molecules,
                surfaceId: "mo-wrap", components: [
                Component(id: "root", type: "Column", properties: ["children": ["sw", "desc"]]),
                Component(id: "sw", type: "SelectionWrap", properties: [
                    "items": [
                        ["value": "light", "child": "c_light"] as [String: Any],
                        ["value": "rich", "child": "c_rich"] as [String: Any],
                        ["value": "bold", "child": "c_bold"] as [String: Any],
                    ] as [JsonMap],
                    "selection": ["path": "/wrap"] as JsonMap,
                    "maxSelection": 1
                ]),
                Component(id: "c_light", type: "Text", properties: ["text": "Light & Clean", "variant": "body"]),
                Component(id: "c_rich", type: "Text", properties: ["text": "Rich & Bold", "variant": "body"]),
                Component(id: "c_bold", type: "Text", properties: ["text": "Spicy", "variant": "body"]),
                Component(id: "desc", type: "Text", properties: [
                    "text": "标签形式单选/多选",
                    "variant": "caption"
                ]),
            ], dataModel: ["wrap": ["light"]])
    }

    private static func dropdownSection() -> Section {
        Section(name: "下拉菜单组件", category: "复合组件", categoryColor: molecules,
                surfaceId: "mo-dropdown", components: [
                Component(id: "root", type: "Column", properties: ["children": ["dd", "desc"]]),
                Component(id: "dd", type: "DropdownSelection", properties: [
                    "selection": ["path": "/location"] as JsonMap,
                    "items": ["北京", "上海", "广州", "深圳"],
                    "placeholder": "选择地点"
                ]),
                Component(id: "desc", type: "Text", properties: [
                    "text": "点击浮出二级选项",
                    "variant": "caption"
                ]),
            ], dataModel: ["location": []])
    }

    // MARK: - 容器组件 (Organisms)

    private static func dateTimePickerSection() -> Section {
        Section(name: "日期时间选择 (Pickers)", category: "容器组件", categoryColor: organisms,
                surfaceId: "mo-datetime", components: [
                Component(id: "root", type: "Column", properties: ["children": ["dt", "desc"]]),
                Component(id: "dt", type: "DateTimeInput", properties: [
                    "value": ["path": "/date"] as JsonMap,
                    "label": "预订日期",
                    "variant": "date"
                ]),
                Component(id: "desc", type: "Text", properties: [
                    "text": "表单中精确到日/时的选择",
                    "variant": "caption"
                ]),
            ], dataModel: ["date": ""])
    }

    private static func selectionGridSection() -> Section {
        Section(name: "九宫格多选/单选", category: "容器组件", categoryColor: organisms,
                surfaceId: "mo-grid", components: [
                Component(id: "root", type: "Column", properties: ["children": ["sg", "desc"]]),
                Component(id: "sg", type: "SelectionGrid", properties: [
                    "items": [
                        ["value": "a", "child": "ga"] as [String: Any],
                        ["value": "b", "child": "gb"] as [String: Any],
                        ["value": "c", "child": "gc"] as [String: Any],
                        ["value": "d", "child": "gd"] as [String: Any],
                        ["value": "e", "child": "ge"] as [String: Any],
                        ["value": "f", "child": "gf"] as [String: Any],
                    ] as [JsonMap],
                    "selection": ["path": "/grid"] as JsonMap,
                    "maxSelection": 2
                ]),
                Component(id: "ga", type: "Column", properties: ["children": ["ga_icon", "ga_t"]]),
                Component(id: "ga_icon", type: "Icon", properties: ["icon": "star", "size": 32, "color": "orange"]),
                Component(id: "ga_t", type: "Text", properties: ["text": "食材A", "variant": "caption"]),
                Component(id: "gb", type: "Column", properties: ["children": ["gb_icon", "gb_t"]]),
                Component(id: "gb_icon", type: "Icon", properties: ["icon": "favorite", "size": 32, "color": "red"]),
                Component(id: "gb_t", type: "Text", properties: ["text": "食材B", "variant": "caption"]),
                Component(id: "gc", type: "Column", properties: ["children": ["gc_icon", "gc_t"]]),
                Component(id: "gc_icon", type: "Icon", properties: ["icon": "leaf", "size": 32, "color": "green"]),
                Component(id: "gc_t", type: "Text", properties: ["text": "食材C", "variant": "caption"]),
                Component(id: "gd", type: "Column", properties: ["children": ["gd_icon", "gd_t"]]),
                Component(id: "gd_icon", type: "Icon", properties: ["icon": "flame", "size": 32, "color": "orange"]),
                Component(id: "gd_t", type: "Text", properties: ["text": "食材D", "variant": "caption"]),
                Component(id: "ge", type: "Column", properties: ["children": ["ge_icon", "ge_t"]]),
                Component(id: "ge_icon", type: "Icon", properties: ["icon": "drop", "size": 32, "color": "blue"]),
                Component(id: "ge_t", type: "Text", properties: ["text": "食材E", "variant": "caption"]),
                Component(id: "gf", type: "Column", properties: ["children": ["gf_icon", "gf_t"]]),
                Component(id: "gf_icon", type: "Icon", properties: ["icon": "bolt", "size": 32, "color": "yellow"]),
                Component(id: "gf_t", type: "Text", properties: ["text": "食材F", "variant": "caption"]),
                Component(id: "desc", type: "Text", properties: [
                    "text": "图文选择器，右上角勾选标记",
                    "variant": "caption"
                ]),
            ], dataModel: ["grid": []], fixedHeight: 200)
    }

    private static func orderedSelectionListSection() -> Section {
        Section(name: "优先级排序组件", category: "容器组件", categoryColor: organisms,
                surfaceId: "mo-ordered-sel", components: [
                Component(id: "root", type: "Column", properties: ["children": ["osl", "desc"]]),
                Component(id: "osl", type: "OrderedSelectionList", properties: [
                    "items": [
                        ["value": "a", "child": "oa"] as [String: Any],
                        ["value": "b", "child": "ob"] as [String: Any],
                        ["value": "c", "child": "oc"] as [String: Any],
                    ] as [JsonMap],
                    "selection": ["path": "/ordered"] as JsonMap,
                    "maxSelection": 3,
                    "requiredSelection": 1
                ]),
                Component(id: "oa", type: "Text", properties: ["text": "首要目标", "variant": "body"]),
                Component(id: "ob", type: "Text", properties: ["text": "次要目标", "variant": "body"]),
                Component(id: "oc", type: "Text", properties: ["text": "第三目标", "variant": "body"]),
                Component(id: "desc", type: "Text", properties: [
                    "text": "带红色数字序号的优先级选择",
                    "variant": "caption"
                ]),
            ], dataModel: ["ordered": []])
    }

    private static func rollPickerSection() -> Section {
        Section(name: "老虎机 (RollPicker)", category: "容器组件", categoryColor: organisms,
                surfaceId: "mo-roll", components: [
                Component(id: "root", type: "Column", properties: ["children": ["rp", "desc"]]),
                Component(id: "rp", type: "RollPicker", properties: [
                    "columns": [
                        ["title": "吃什么", "items": ["火锅", "烧烤", "日料", "西餐"]] as [String: Any],
                        ["title": "预算", "items": ["¥50", "¥100", "¥200"]] as [String: Any],
                    ] as [JsonMap],
                    "selection": ["path": "/roll"] as JsonMap
                ]),
                Component(id: "desc", type: "Text", properties: [
                    "text": "滚轮选择，支持多列",
                    "variant": "caption"
                ]),
            ], dataModel: ["roll": ["吃什么", "预算"]], fixedHeight: 180)
    }

    private static func rollPickerCardSection() -> Section {
        Section(name: "老虎机卡片 (RollPickerCard)", category: "容器组件", categoryColor: organisms,
                surfaceId: "mo-roll-card", components: [
                Component(id: "root", type: "RollPickerCard", properties: [
                    "columns": [
                        ["title": "吃什么", "items": ["火锅", "烧烤", "日料"]] as [String: Any],
                        ["title": "预算", "items": ["¥50", "¥100", "¥200"]] as [String: Any],
                    ] as [JsonMap],
                    "selection": ["path": "/rollCard"] as JsonMap,
                    "action": ["name": "spin"] as JsonMap
                ]),
            ], dataModel: ["rollCard": ["吃什么", "预算"]], fixedHeight: 280)
    }

    private static func carouselSection() -> Section {
        Section(name: "菜单横滑 (Carousel)", category: "容器组件", categoryColor: organisms,
                surfaceId: "mo-carousel", components: [
                Component(id: "root", type: "Carousel", properties: [
                    "children": ["explicitList": ["page1", "page2", "page3"]] as [String: Any]
                ]),
                Component(id: "page1", type: "Card", properties: ["child": "p1c"]),
                Component(id: "p1c", type: "Column", properties: ["children": ["p1t", "p1d"]]),
                Component(id: "p1t", type: "Text", properties: ["text": "菜谱 1", "variant": "h4"]),
                Component(id: "p1d", type: "Text", properties: ["text": "特价推荐", "variant": "body"]),
                Component(id: "page2", type: "Card", properties: ["child": "p2c"]),
                Component(id: "p2c", type: "Column", properties: ["children": ["p2t", "p2d"]]),
                Component(id: "p2t", type: "Text", properties: ["text": "菜谱 2", "variant": "h4"]),
                Component(id: "p2d", type: "Text", properties: ["text": "人气爆款", "variant": "body"]),
                Component(id: "page3", type: "Card", properties: ["child": "p3c"]),
                Component(id: "p3c", type: "Column", properties: ["children": ["p3t", "p3d"]]),
                Component(id: "p3t", type: "Text", properties: ["text": "菜谱 3", "variant": "h4"]),
                Component(id: "p3d", type: "Text", properties: ["text": "新品上市", "variant": "body"]),
            ], fixedHeight: 200)
    }

    private static func tickSliderSection() -> Section {
        Section(name: "离散滑块 (TickSlider)", category: "容器组件", categoryColor: organisms,
                surfaceId: "mo-tickslider", components: [
                Component(id: "root", type: "TickSlider", properties: [
                    "value": ["path": "/tick"] as JsonMap,
                    "max": ["path": "/tickMax"] as JsonMap
                ]),
            ], dataModel: ["tick": 3, "tickMax": 5], fixedHeight: 140)
    }

    private static func passwordKeypadSection() -> Section {
        Section(name: "计算器/密码键盘 (PasswordKeypad)", category: "容器组件", categoryColor: organisms,
                surfaceId: "mo-keypad", components: [
                Component(id: "root", type: "PasswordKeypad", properties: [
                    "value": ["path": "/pin"] as JsonMap,
                    "action": ["name": "submit"] as JsonMap
                ]),
            ], dataModel: ["pin": ""], fixedHeight: 360)
    }
}

// MARK: - Badge Label

private class BadgeLabel: UILabel {
    var padding = UIEdgeInsets.zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: padding))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + padding.left + padding.right,
            height: size.height + padding.top + padding.bottom
        )
    }
}
