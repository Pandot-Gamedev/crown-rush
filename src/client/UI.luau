-- Helpers for building the on-screen menus in code, so nothing has to be
-- drawn by hand in Studio. Colors and fonts live in UI.Theme.

local UI = {}

UI.Theme = {
	Background = Color3.fromRGB(20, 32, 52),
	Panel = Color3.fromRGB(30, 46, 74),
	Card = Color3.fromRGB(42, 62, 96),
	Accent = Color3.fromRGB(60, 170, 255),
	Gold = Color3.fromRGB(255, 200, 40),
	Good = Color3.fromRGB(70, 200, 110),
	Bad = Color3.fromRGB(230, 80, 80),
	Muted = Color3.fromRGB(150, 170, 200),
	Text = Color3.fromRGB(255, 255, 255),
	Font = Enum.Font.FredokaOne,
	BodyFont = Enum.Font.GothamMedium,
}

local T = UI.Theme

-- UI.new("Frame", { Size = ..., Parent = ... }, { child1, child2 })
function UI.new(className, props, children)
	local instance = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			instance[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = instance
	end
	instance.Parent = parent
	return instance
end

function UI.corner(radius)
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

function UI.stroke(color, thickness)
	return UI.new("UIStroke", {
		Color = color or Color3.new(0, 0, 0),
		Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UI.padding(pixels)
	local p = UDim.new(0, pixels)
	return UI.new("UIPadding", { PaddingTop = p, PaddingBottom = p, PaddingLeft = p, PaddingRight = p })
end

function UI.list(spacing, direction)
	return UI.new("UIListLayout", {
		Padding = UDim.new(0, spacing or 8),
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function UI.label(text, props)
	local label = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = T.Text,
		Font = T.Font,
		TextScaled = true,
		Size = UDim2.new(1, 0, 0, 24),
	})
	for key, value in pairs(props or {}) do
		label[key] = value
	end
	return label
end

function UI.button(text, color, onClick, props)
	local button = UI.new("TextButton", {
		Text = text,
		BackgroundColor3 = color or T.Accent,
		TextColor3 = T.Text,
		Font = T.Font,
		TextScaled = true,
		AutoButtonColor = true,
		Size = UDim2.fromOffset(120, 40),
	}, {
		UI.corner(8),
		UI.new("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	})
	for key, value in pairs(props or {}) do
		button[key] = value
	end
	if onClick then
		button.Activated:Connect(onClick)
	end
	return button
end

function UI.clear(container)
	for _, child in ipairs(container:GetChildren()) do
		child:Destroy()
	end
end

-- A centered window with a title, a close button and a scrolling body.
-- Only one window is open at a time.
local openWindow = nil
local windowChanged = Instance.new("BindableEvent")
UI.WindowChanged = windowChanged.Event -- fires with true/false when a window opens/closes

function UI.IsWindowOpen()
	return openWindow ~= nil
end

function UI.window(screenGui, title, render)
	local frame = UI.new("Frame", {
		Name = title .. "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(620, 440),
		BackgroundColor3 = T.Panel,
		Visible = false,
		Active = true, -- clicks on the window don't reach the game (no bonking through it)
		ZIndex = 10, -- above the HUD and the guide card, so the close button is never covered
		Parent = screenGui,
	}, { UI.corner(16), UI.stroke(T.Background, 4) })

	UI.label(title, {
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(1, -90, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})

	local body = UI.new("ScrollingFrame", {
		Name = "Body",
		Position = UDim2.fromOffset(16, 60),
		Size = UDim2.new(1, -32, 1, -76),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = frame,
	})

	local window = { frame = frame, body = body }

	function window.refresh()
		if frame.Visible then
			UI.clear(body)
			render(body)
		end
	end

	function window.open()
		if openWindow and openWindow ~= window then
			openWindow.close()
		end
		openWindow = window
		frame.Visible = true
		window.refresh()
		windowChanged:Fire(true)
	end

	function window.close()
		frame.Visible = false
		if openWindow == window then
			openWindow = nil
			windowChanged:Fire(false)
		end
	end

	function window.toggle()
		if frame.Visible then
			window.close()
		else
			window.open()
		end
	end

	UI.button("X", T.Bad, window.close, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromOffset(40, 40),
		Parent = frame,
	})

	return window
end

return UI
