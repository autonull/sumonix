package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/marcusolsson/tui-go"
)

type StatusJSON struct {
	Services      int    `json:"services"`
	Packages      int    `json:"packages"`
	Capabilities  int    `json:"capabilities"`
	Rounds        int    `json:"rounds"`
	Verdict       string `json:"verdict"`
	Proof         string `json:"proof"`
}

type CapsJSON struct {
	DirectCompositions  int `json:"directCompositions"`
	EnabledCapabilities int `json:"enabledCapabilities"`
	Synergies           int `json:"synergies"`
}

type QueryJSON struct {
	Goal    string `json:"goal"`
	Derived int    `json:"derived"`
	Proof   string `json:"proof"`
}

type WhatIfCandidate struct {
	Name  string `json:"name"`
	Flip  bool   `json:"flip"`
	Proof string `json:"proof"`
}

type WhatIfJSON struct {
	BasePass    bool              `json:"basePass"`
	BaseDerived bool              `json:"baseDerived"`
	Flips       int               `json:"flips"`
	Candidates  []WhatIfCandidate `json:"candidates"`
}

type TopologyJSON struct {
	Screens []struct {
		ID    string `json:"id"`
		Title string `json:"title"`
		Desc  string `json:"desc"`
	} `json:"screens"`
	Keys []struct {
		Key    string `json:"key"`
		Action string `json:"action"`
	} `json:"keys"`
}

type DashboardData struct {
	Status    *StatusJSON
	Caps      *CapsJSON
	Query     *QueryJSON
	WhatIf    *WhatIfJSON
	Topology  *TopologyJSON
	LastUpdate time.Time
}

var (
	dumpMode = flag.Bool("dump", false, "Render TUI to stdout without TTY (for screenshot capture)")
	sumoBin  = flag.String("sumo", "sumo", "Path to sumo binary")
)

func main() {
	flag.Parse()

	if *dumpMode {
		runDumpMode()
		return
	}

	runInteractiveMode()
}

func runDumpMode() {
	data := fetchAllData()
	renderDump(data)
	os.Exit(0)
}

func runInteractiveMode() {
	data := fetchAllData()

	ui, err := NewDashboardUI(data)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating UI: %v\n", err)
		os.Exit(1)
	}

	go ui.autoRefresh()

	if err := ui.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error running UI: %v\n", err)
		os.Exit(1)
	}
}

func fetchAllData() *DashboardData {
	data := &DashboardData{LastUpdate: time.Now()}

	// Fetch status
	if out, err := runSumo("status", "--json"); err == nil {
		var s StatusJSON
		if err := json.Unmarshal([]byte(out), &s); err == nil {
			data.Status = &s
		}
	}

	// Fetch caps
	if out, err := runSumo("caps", "--json"); err == nil {
		var c CapsJSON
		if err := json.Unmarshal([]byte(out), &c); err == nil {
			data.Caps = &c
		}
	}

	// Fetch whatif
	if out, err := runSumo("whatif", "--json"); err == nil {
		var w WhatIfJSON
		if err := json.Unmarshal([]byte(out), &w); err == nil {
			data.WhatIf = &w
		}
	}

	// Fetch topology
	data.Topology = &TopologyJSON{
		Screens: []struct {
			ID    string `json:"id"`
			Title string `json:"title"`
			Desc  string `json:"desc"`
		}{
			{ID: "status", Title: "Machine Status", Desc: "Services, packages, capabilities, rounds, policy verdict"},
			{ID: "caps", Title: "Capability Atlas", Desc: "Direct compositions, enabled capabilities, synergies"},
			{ID: "closure", Title: "Package Closure", Desc: "Dependency tree for a package"},
			{ID: "query", Title: "Query Goal", Desc: "Ground goal → verdict + why subtree"},
			{ID: "whatif", Title: "What-If Analysis", Desc: "One counterfactual from the proof"},
			{ID: "dashboard", Title: "Dashboard", Desc: "TUI: services, capabilities, policy proof, charts"},
		},
		Keys: []struct {
			Key    string `json:"key"`
			Action string `json:"action"`
		}{
			{Key: "h", Action: "Show this topology (help)"},
			{Key: "?", Action: "Show this topology (help)"},
			{Key: "q", Action: "Quit dashboard"},
			{Key: "Tab", Action: "Navigate panes"},
			{Key: "Arrows", Action: "Scroll proof / resize panes"},
			{Key: "w", Action: "Show what-if card"},
		},
	}

	return data
}

func runSumo(args ...string) (string, error) {
	cmd := exec.Command(*sumoBin, args...)
	cmd.Dir = "/home/me/sumonix"
	out, err := cmd.CombinedOutput()
	return string(out), err
}

func renderDump(data *DashboardData) {
	fmt.Println("╔════════════════════════════════════════════════════════════════════╗")
	fmt.Println("║                        MACHINE STATUS                             ║")
	fmt.Println("╚════════════════════════════════════════════════════════════════════╝")
	fmt.Println()
	if data.Status != nil {
		fmt.Printf("📦 Services: %d\n", data.Status.Services)
		fmt.Printf("📦 Packages: %d\n", data.Status.Packages)
		fmt.Printf("⚡ Capabilities: %d\n", data.Status.Capabilities)
		fmt.Printf("🔄 Derivation rounds: %d\n", data.Status.Rounds)
		fmt.Println()
		fmt.Println("─────────────────────────────────────────────────────────────")
		fmt.Printf("🚦 POLICY GATE: %s\n", strings.ToUpper(data.Status.Verdict))
		fmt.Println(data.Status.Proof)
		fmt.Println("─────────────────────────────────────────────────────────────")
	}
	fmt.Println()
	fmt.Println("Run: sumo caps | sumo closure <pkg> | sumo query <goal> | sumo whatif | sumo dashboard")
	fmt.Println()
	fmt.Println("╔════════════════════════════════════════════════════════════════════╗")
	fmt.Println("║           SUMO-NIX CAPABILITY DISCOVERY                         ║")
	fmt.Println("║       \"What novel capabilities can I compose?\"                  ║")
	fmt.Println("╚════════════════════════════════════════════════════════════════════╝")
	fmt.Println()
	if data.Caps != nil {
		fmt.Printf("📦 DIRECT COMPOSITIONS (%d) — package + immediate deps:\n", data.Caps.DirectCompositions)
		fmt.Println("  (run 'sumo caps' for details)")
		fmt.Println()
		fmt.Printf("🌐 ENABLED CAPABILITIES (%d) — via transitive dependency closure:\n", data.Caps.EnabledCapabilities)
		fmt.Println("  (run 'sumo caps' for details)")
		fmt.Println()
		fmt.Printf("💡 SYNERGIES (%d) — 3+ capabilities combining:\n", data.Caps.Synergies)
		fmt.Println("  (run 'sumo caps' for details)")
		fmt.Println()
		fmt.Println("─────────────────────────────────────────────────────────────")
		fmt.Println("✨ Your nixpkgs is a capability goldmine.")
	}
	fmt.Println()
	if data.WhatIf != nil {
		fmt.Printf("Base verdict: %s\n\n", map[bool]string{true: "PASS", false: "VIOLATION"}[data.WhatIf.BasePass])
		fmt.Println("Single flips that change the verdict:")
		for _, c := range data.WhatIf.Candidates {
			if c.Flip {
				fmt.Printf("  ✓ %s\n", c.Name)
			}
		}
		fmt.Println()
		if hasNonFlip(data.WhatIf.Candidates) {
			fmt.Println("Other candidates:")
			for _, c := range data.WhatIf.Candidates {
				if !c.Flip {
					fmt.Printf("  ✗ %s (flips nothing)\n", c.Name)
				}
			}
		}
	}
}

type DashboardUI struct {
	data       *DashboardData
	ui         tui.UI
	root       tui.Widget
	showWhatIf bool
}

func NewDashboardUI(data *DashboardData) (*DashboardUI, error) {
	dui := &DashboardUI{data: data}
	dui.root = dui.buildUI()
	ui, err := tui.New(dui.root)
	if err != nil {
		return nil, err
	}
	dui.ui = ui

	ui.SetKeybinding("q", func() { ui.Quit() })
	ui.SetKeybinding("Tab", func() { dui.nextPane() })
	ui.SetKeybinding("h", func() { dui.showHelp() })
	ui.SetKeybinding("?", func() { dui.showHelp() })
	ui.SetKeybinding("w", func() { dui.toggleWhatIf() })

	return dui, nil
}

func (dui *DashboardUI) buildUI() tui.Widget {
	header := dui.buildHeader()
	left := dui.buildLeftPane()
	right := dui.buildRightPane()
	bottom := dui.buildBottomPane()

	mainLayout := tui.NewVBox(
		header,
		tui.NewHBox(left, right),
		bottom,
	)

	return mainLayout
}

func (dui *DashboardUI) buildHeader() tui.Widget {
	var verdictBadge string
	if dui.data.Status != nil {
		if dui.data.Status.Verdict == "violation" {
			verdictBadge = "POLICY: VIOLATION"
		} else {
			verdictBadge = "POLICY: PASS"
		}
	} else {
		verdictBadge = "POLICY: UNKNOWN"
	}

	headerText := fmt.Sprintf("  sumonix dashboard | nginx | pkgs %d | caps %d | rules %d | %s",
		dui.getPackageCount(), dui.getCapabilityCount(), dui.getRuleCount(), verdictBadge)

	header := tui.NewLabel(headerText)
	headerBox := tui.NewVBox(header)
	headerBox.SetBorder(true)
	return headerBox
}

func (dui *DashboardUI) getPackageCount() int {
	if dui.data.Status != nil {
		return dui.data.Status.Packages
	}
	return 6
}

func (dui *DashboardUI) getCapabilityCount() int {
	if dui.data.Status != nil {
		return dui.data.Status.Capabilities
	}
	return 0
}

func (dui *DashboardUI) getRuleCount() int {
	return 286
}

func (dui *DashboardUI) buildLeftPane() tui.Widget {
	vbox := tui.NewVBox()

	// Services / Installed pane
	servicesLabel := tui.NewLabel("SERVICES / INSTALLED")
	servicesBox := tui.NewVBox(servicesLabel)
	servicesBox.SetBorder(true)
	servicesBox.SetTitle(" SERVICES ")
	vbox.Append(servicesBox)

	servicesContent := tui.NewLabel(dui.getServicesContent())
	servicesContent.SetWordWrap(true)
	servicesContentBox := tui.NewVBox(servicesContent)
	servicesContentBox.SetBorder(true)
	vbox.Append(servicesContentBox)

	// Capability atlas pane
	capsLabel := tui.NewLabel("CAPABILITY ATLAS")
	capsBox := tui.NewVBox(capsLabel)
	capsBox.SetBorder(true)
	capsBox.SetTitle(" CAPABILITIES ")
	vbox.Append(capsBox)

	capsContent := tui.NewLabel(dui.getCapsContent())
	capsContent.SetWordWrap(true)
	capsContentBox := tui.NewVBox(capsContent)
	capsContentBox.SetBorder(true)
	vbox.Append(capsContentBox)

	// Capability sparkline chart
	chartLabel := tui.NewLabel("CAPABILITY SPARKLINE")
	chartBox := tui.NewVBox(chartLabel)
	chartBox.SetBorder(true)
	chartBox.SetTitle(" CHART ")
	vbox.Append(chartBox)

	chartContent := tui.NewLabel(dui.getCapabilitySparkline())
	chartContent.SetWordWrap(true)
	chartContentBox := tui.NewVBox(chartContent)
	chartContentBox.SetBorder(true)
	vbox.Append(chartContentBox)

	vbox.SetBorder(true)
	vbox.SetTitle(" LEFT ")
	return vbox
}

func (dui *DashboardUI) getServicesContent() string {
	if dui.data.Status == nil {
		return "  Loading..."
	}
	return fmt.Sprintf("  Services: %d\n  Packages: %d\n  Capabilities: %d\n  Rounds: %d",
		dui.data.Status.Services, dui.data.Status.Packages, dui.data.Status.Capabilities, dui.data.Status.Rounds)
}

func (dui *DashboardUI) getCapsContent() string {
	if dui.data.Caps == nil {
		return "  Loading..."
	}
	return fmt.Sprintf("  Direct compositions: %d\n  Enabled capabilities: %d\n  Synergies: %d",
		dui.data.Caps.DirectCompositions, dui.data.Caps.EnabledCapabilities, dui.data.Caps.Synergies)
}

func (dui *DashboardUI) getCapabilitySparkline() string {
	if dui.data.Caps == nil {
		return "  Loading..."
	}
	// Simple ASCII sparkline for capability categories
	values := []int{dui.data.Caps.DirectCompositions, dui.data.Caps.EnabledCapabilities, dui.data.Caps.Synergies}
	labels := []string{"Direct", "Enabled", "Synergy"}
	maxVal := 1
	for _, v := range values {
		if v > maxVal {
			maxVal = v
		}
	}

	var sb strings.Builder
	for i, v := range values {
		barLen := 20 * v / maxVal
		if barLen == 0 && v > 0 {
			barLen = 1
		}
		bar := strings.Repeat("█", barLen) + strings.Repeat("░", 20-barLen)
		sb.WriteString(fmt.Sprintf("  %s: [%s] %d\n", labels[i], bar, v))
	}
	return sb.String()
}

func (dui *DashboardUI) buildRightPane() tui.Widget {
	vbox := tui.NewVBox()

	// Policy pane
	policyLabel := tui.NewLabel("POLICY VERDICT & PROOF")
	policyBox := tui.NewVBox(policyLabel)
	policyBox.SetBorder(true)
	policyBox.SetTitle(" POLICY ")
	vbox.Append(policyBox)

	policyContent := tui.NewLabel(dui.getPolicyContent())
	policyContent.SetWordWrap(true)
	policyContentBox := tui.NewVBox(policyContent)
	policyContentBox.SetBorder(true)
	policyContentBox.SetSizePolicy(tui.Preferred, tui.Expanding)
	vbox.Append(policyContentBox)

	// What-if card (shown on 'w' key)
	if dui.showWhatIf && dui.data.WhatIf != nil {
		whatIfLabel := tui.NewLabel("WHAT-IF ANALYSIS")
		whatIfBox := tui.NewVBox(whatIfLabel)
		whatIfBox.SetBorder(true)
		whatIfBox.SetTitle(" WHAT-IF ")
		vbox.Append(whatIfBox)

		whatIfContent := tui.NewLabel(dui.getWhatIfContent())
		whatIfContent.SetWordWrap(true)
		whatIfContentBox := tui.NewVBox(whatIfContent)
		whatIfContentBox.SetBorder(true)
		vbox.Append(whatIfContentBox)
	}

	vbox.SetBorder(true)
	vbox.SetTitle(" RIGHT ")
	return vbox
}

func (dui *DashboardUI) getPolicyContent() string {
	if dui.data.Status == nil {
		return "  Loading..."
	}
	verdict := dui.data.Status.Verdict
	proof := dui.data.Status.Proof
	if len(proof) > 2000 {
		proof = proof[:2000] + "..."
	}
	return fmt.Sprintf("  Verdict: %s\n\n  %s", strings.ToUpper(verdict), proof)
}

func (dui *DashboardUI) getWhatIfContent() string {
	if dui.data.WhatIf == nil {
		return "  Loading..."
	}
	baseVerdict := map[bool]string{true: "PASS", false: "VIOLATION"}[dui.data.WhatIf.BasePass]
	var sb strings.Builder
	sb.WriteString(fmt.Sprintf("  Base verdict: %s\n\n", baseVerdict))
	sb.WriteString("  Flips that change verdict:\n")
	for _, c := range dui.data.WhatIf.Candidates {
		if c.Flip {
			sb.WriteString(fmt.Sprintf("  ✓ %s\n", c.Name))
		}
	}
	if hasNonFlip(dui.data.WhatIf.Candidates) {
		sb.WriteString("\n  No-flip candidates:\n")
		for _, c := range dui.data.WhatIf.Candidates {
			if !c.Flip {
				sb.WriteString(fmt.Sprintf("  ✗ %s\n", c.Name))
			}
		}
	}
	return sb.String()
}

func hasNonFlip(candidates []WhatIfCandidate) bool {
	for _, c := range candidates {
		if !c.Flip {
			return true
		}
	}
	return false
}

func (dui *DashboardUI) buildBottomPane() tui.Widget {
	activity := dui.getActivityContent()
	keys := "Press 'h' for help, 'q' to quit, 'w' for what-if, Tab to navigate"
	bottom := tui.NewLabel(fmt.Sprintf(" ACTIVITY: %s  |  %s ", activity, keys))
	bottomBox := tui.NewVBox(bottom)
	bottomBox.SetBorder(true)
	return bottomBox
}

func (dui *DashboardUI) getActivityContent() string {
	if dui.data.Status == nil {
		return "initializing..."
	}
	return fmt.Sprintf("last update: %s | rounds: %d", dui.data.LastUpdate.Format("15:04:05"), dui.data.Status.Rounds)
}

func (dui *DashboardUI) nextPane() {
	// For now, just cycle through showing help
	dui.showHelp()
}

func (dui *DashboardUI) toggleWhatIf() {
	dui.showWhatIf = !dui.showWhatIf
	dui.root = dui.buildUI()
	dui.ui.SetWidget(dui.root)
	dui.ui.Repaint()
}

func (dui *DashboardUI) showHelp() {
	if dui.data.Topology == nil {
		return
	}
	var sb strings.Builder
	sb.WriteString("SUMONIX DASHBOARD TOPOLOGY\n\n")
	sb.WriteString("SCREENS:\n")
	for _, s := range dui.data.Topology.Screens {
		sb.WriteString(fmt.Sprintf("  %s — %s\n    %s\n", s.ID, s.Title, s.Desc))
	}
	sb.WriteString("\nKEYS:\n")
	for _, k := range dui.data.Topology.Keys {
		sb.WriteString(fmt.Sprintf("  %s — %s\n", k.Key, k.Action))
	}

	helpLabel := tui.NewLabel(sb.String())
	helpLabel.SetWordWrap(true)
	helpBox := tui.NewVBox(helpLabel)
	helpBox.SetBorder(true)
	helpBox.SetTitle(" HELP (press any key to close) ")

	overlay := tui.NewVBox(
		tui.NewSpacer(),
		tui.NewHBox(
			tui.NewSpacer(),
			helpBox,
			tui.NewSpacer(),
		),
		tui.NewSpacer(),
	)

	helpUI, err := tui.New(overlay)
	if err != nil {
		return
	}
	helpUI.SetKeybinding("", func() { helpUI.Quit() })
	helpUI.Run()
}

func (dui *DashboardUI) autoRefresh() {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	for range ticker.C {
		newData := fetchAllData()
		dui.data = newData
		dui.ui.Update(func() {
			dui.root = dui.buildUI()
			dui.ui.SetWidget(dui.root)
			dui.ui.Repaint()
		})
	}
}

func (dui *DashboardUI) Run() error {
	return dui.ui.Run()
}