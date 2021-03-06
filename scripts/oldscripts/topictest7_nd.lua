local gl = require("opengl")
local GL = gl
local glu = require("opengl.glu")
-------------------------------------------------

local vec3 = require("space.vec3")
local Shader = require("opengl.Shader")
local sketch = require("opengl.sketch")

local Texture = require("opengl.Texture")
local Array = require("Array")

local Camera = require("glutils.navcam")

-------------------------------------------------

require("topicnet")
local TopNet = topicnet.Topicnet

------------------Parse Data---------------------
local tpd = TopNet()
--local file = "/data/smallworld_1000_2000.xml"
--local file = "/data/4test.xml"
--local file = "/data/facebook_Donovan_music.xml"
--local file = "/data/UCI_venezuela.xml"
--local file = "/data/facebook_Brynjar Gretarsson_2.dnv"
local file = "/data/coauthor.xml"

local sourcepath = script.path .. file
tpd:loadData(sourcepath, "author")




------------------Save Data----------------------
local
function saveGraph(fileN)
    local path = script.path .. "/data"
    --print("path  ", path)
	local fname = LuaAV.findfileinpath(path, fileN, true)
	--print("filename", fname)
	local f = io.open(fname, "w")
	--print(f)
	
	for s=1, tpd:graphsize() do
		local ind = s-1
	    local p = tpd:graphnodepos(ind)
        f:write(ind," ", p[1]," ", p[2]," ",  p[3], "\n")
	end
	f:close()
end


string.split = function(str, pattern)
  pattern = pattern or "[^%s]+"
  if pattern:len() == 0 then pattern = "[^%s]+" end
  local parts = {__index = table.insert}
  setmetatable(parts, parts)
  str:gsub(pattern, parts)
  setmetatable(parts, nil)
  parts.__index = nil
  return parts
end


local
function loadGraph(fileN)
    local path = script.path .. "/data"
    --print("path  ", path)
	local fname = LuaAV.findfileinpath(path, fileN, true)
	--print("filename", fname)
	local f = io.open(fname, "r")
	--print(f)
	
	local lineNum = 0
	if f then
		--print("file open")
		for line in f:lines() do 
	    	lineNum = lineNum + 1
	    	local parts = line:split( "[^,%s]+" )
	    	local pos = {parts[2], parts[3], parts[4]}
	    	--print(parts[1], parts[2], parts[3], parts[4])
	    	tpd:graphnodepos(parts[1], pos)
	    end
	end
	
	f:close()
end
-------------------------------------------------
local context = "3d net test"
win = Window{
	title = context, 
	origin = {0, 0}, 
	dim = {600, 480},
	mousemove = true,
}

win.sync = true
win.stereo = false

------------------global variables---------------

local RADIUS = 0.05
local HALOSIZE = 1.1


local boolstereo = false
local layout3d = false
local draw3d = true

local activePlane = -1

local mouseinteractmode = 0

local lastx
local lasty

local cvec1 = {0.0, 0.0, 0.0}
local cvec2 ={0.0, 0.0, 0.0}

local ray = {0.0, 0.0, 0.0}
local selectednodeindex = -1

local boolmousepress = false
local nodedragged = false

local n1high = false
local n2high = false


local AREA = 5.0
local MAXSTEP = 550
local TEMP = 0.5

local st = 0

---------------------colors----------------------
local red2 = {247/255, 59/255, 81/255}
local green2 = {84/255, 157/255, 138/255}
local yellow2 = {251/255, 252/255, 89/255}
local blue1 = {98/255, 202/255, 215/255}

-------------------------------------------------

local shapeTexture = Texture(context)
local 
function initTexture()

    local res = 256
    local float1 = Array(4, Array.Float32, {res, res})
	
	for i=0, float1.dim[1]-1 do
	for j=0, float1.dim[2]-1 do
	
		--textures for normal coefficient lookup. x is across profile, y is rotation index.
		--all profile lookups are stored as if they were in an orthogonal projection, making things easier.
		--red coefficient is stored packed, meaning 0 to 1 really maps to -1 to 1
		
		local x = ((j/res) * 2.0) - 1.0
		local y = i/res

		--r channel contains side vector coefficient
		--g channel contains up vector coefficient
		--b channel contains depth correction factor

		local r, g, b
		
		local angle = y * math.pi
		local center = -math.cos(angle)

		if (x < center) then 
			r = - math.cos(angle*0.5) * 0.5 + 0.5
			g = math.sin(angle*0.5)
		else
			r = math.sin(angle*0.5) * 0.5 + 0.5
			g = math.cos(angle*0.5)
		end
		
			b = math.sqrt(1.0 - x*x)

		float1:setcell(i, j, {r, g, b, 1.0})
	end
	end

	shapeTexture:fromarray(float1)
	
end
-------------------------------------------------
local Gui = require("gui.Context")
local Rect = require("gui.Rect")
local Slider = require("gui.Slider")
local Button = require("gui.Button")
local GuiLabel = require("gui.Label")

local Label = require("Label")
-------------------------------------------------

local guilabels = Label{
	ctx = context,
	size = 12,
	color = {1.0, 0.3, 0.1}
}

local graphlabels = Label{
	ctx = context,
	fontfile = LuaAV.findfile("GilSans.ttf"),
	alignment = "LEFT",
	size = 12,
	bg = true,
}

-- create the gui
local gui = Gui{
	ctx = context,
	dim = win.dim,
}

-- create some widgets
local mv_nd_btn = Button{
	rect = Rect(10, 12, 15, 15),
	value = false,
}

local nd_btn = Button{
	rect = Rect(10, 30, 15, 15),
	value = false,
}

local pl_btn = Button{
	rect = Rect(10, 50, 15, 15),
	value = false,
}

local clr_g_channel = Slider{
	rect = Rect(10, 110, 100, 10),
	value = 0.79,
	range = {0, 1},
}

local linethick = Slider{
	rect = Rect(10, 170, 100, 10),
	value = 1,
	range = {0, 3},
}

local pointsz = Slider{
	rect = Rect(10, 210, 100, 10),
	value = 12,
	range = {5, 20},
}

-- add them to the gui
gui:add_view(mv_nd_btn)
gui:add_view(nd_btn)
gui:add_view(pl_btn)

gui:add_view(clr_g_channel)
gui:add_view(linethick)
gui:add_view(pointsz)



-- register for notifications

mv_nd_btn:register("value", function(w)
	local val = w.value 
	print(val)
	if val then 
		mouseinteractmode = 0 
		pl_btn.value = false
		nd_btn.value = false
	end
end)

nd_btn:register("value", function(w)
	local val = w.value 
	print(val)
	if val then 
		mouseinteractmode = 1 
		pl_btn.value = false
		mv_nd_btn.value = false
	end
end)

pl_btn:register("value", function(w)
	local val = w.value 
	print(val)
	if val then 
		mouseinteractmode = 2 
		nd_btn.value = false
		mv_nd_btn.value = false
	end
end)

clr_g_channel:register("value", function(w)
	blue1[2] = w.value 
end)

-------------------------------------------------

local cam = Camera()

cam:movex(-2.5);
cam:movey(2.5);
cam:movez(-2.5)

cam.stereo = false

local function redrawgraph()
	tpd:initGraphLayout()
	tpd:randomizeGraph(layout3d)
	print("islayout3d ", layout3d)
	st = 0
	coolexp = COOLING
	maxstep = MAXSTP
	
end

-------------------------------------------------

local 
function addNodeToPlane()
	--find the plane that selectednode z closest to
	-- if there are planes added 
	local currentpos = tpd:selectedNodePos()
	local diff = 100.0
	local plane = -1
	for p=0, tpd:planeCount()-1 do 
		local dist = math.abs(currentpos[3] - tpd:planeDepth(p))
		if(diff > dist) then
			diff = dist
			plane = p
		end
	end
	--print("selectedplane", plane)
	if(plane ~= 0 ) then
		tpd:addNodeToPlane(plane, selectednodeindex) 
	else
		currentpos[3] = 0.0
		tpd:selectedNodePos(currentpos)
	end	
end

-------------------------------------------------

-------------------------------------------------

function win:key(event, key)
     --print(key)
	 if(event == "down") then
		if(key == 27) then
			self.fullscreen = not self.fullscreen
		elseif(key == 101) then --E
			self.stereo = not self.stereo
			cam.stereo = self.stereo
		elseif(key == 105 or key == 73) then --i
			tpd:initGraphLayout()
			tpd:testGrid()
			st = 0
			coolexp = 0.2
		elseif(key == 115) then --S
			saveGraph("graphpos.txt")
		elseif(key == 108) then --L
		    loadGraph("graphpos.txt")
		    st = MAXSTEP -- TO STOP GRAPH LAYOUT CALC
		elseif(key == 121) then --3
			layout3d = not layout3d
			redrawgraph()
		elseif(key == 116) then --T
			draw3d = not draw3d
			--redrawgraph()
		
		elseif(key == 110) then --N
			tpd:bringN1(selectednodeindex)
			n1high = true
	    elseif(key == 109) then --M
			tpd:bringN2(selectednodeindex)
			
		elseif(key == 103) then --G
			mouseinteractmode = 1
		elseif(key == 102) then --F
			mouseinteractmode = 2
		elseif(key == 104) then --H
			n1high = not n1high

		elseif(key == 112) then --P
		  local crrp = tpd:planeCount()
		  crrp = crrp+1
		  tpd:addPlane((crrp * 0.5) - 0.5)
		  activePlane = tpd:planeCount()-1
		  
		elseif(key == 114) then --R
		  tpd:removePlane()
		  activePlane = tpd:planeCount() -1 
		  if(tpd:planeCount() == 1) then activePlane = -1 end
		     
		elseif(key == 106) then --J
		   activePlane = activePlane + 1
		   activePlane = activePlane % tpd:planeCount() 
		   if(tpd:planeCount() == 1) then activePlane = -1 end
		   if(activePlane == 0) then activePlane = 1 end
		end
	end
	
	cam:key(self, event, key)
	gui:key(event, key)
	
end

function win:mouse(event, btn, x, y, nclk)
	gui:mouse(event, btn, x, y, nclk)
	
	if(event == "down") then
		boolmousepress = true
	elseif(event == "up") then
	    boolmousepress = false
	    if(nodedragged) then
	    	nodedragged = false
	    	addNodeToPlane()
	    end
	    
	elseif(event == "drag") then
	    local xdiff = (lastx - x) * 0.01
	    local ydiff = (lasty - y) * 0.01
	    if(mouseinteractmode == 2) then
	      	tpd:movePlane(activePlane, xdiff)
	    elseif(mouseinteractmode == 1) then
			if(selectednodeindex > -1.0 ) then 
				--print("drag selected node: ", selectednodeindex, "by : ", xdiff)
				local currentpos = tpd:selectedNodePos()
				currentpos[3] = currentpos[3] + xdiff
				tpd:selectedNodePos(currentpos)	
				nodedragged = true
			end
		elseif(mouseinteractmode == 0) then
			if(selectednodeindex > -1.0 ) then 
				local amnt = {-xdiff, ydiff, 0.0}
		        tpd:moveGraph(amnt)
			end
		end
	end
	
	lastx, lasty = x, y
end

function win:resize()
    cam:resize(self)
	gui:resize(self.dim)
end

function win:modifiers()
	gui:modifiers(self)
end

-------------------------------------------------


local 
function drawSphere (r, lats, longs)
   for i=1, lats do
  		local lat0 = math.pi * (-0.5 + (i-1)/lats)
        local z0 = math.sin(lat0)
        local zr0 = math.cos(lat0)
         
        local lat1 = math.pi * (-0.5 + i/lats)
        local z1 = math.sin(lat1)
        local zr1 = math.cos(lat1)
        
        gl.Begin(GL.TRIANGLE_STRIP)
        	for j=1, longs+1 do
        		local lng = 2 * math.pi * (j - 1) / longs
        		local x = math.cos(lng)
        		local y = math.sin(lng)
        		
        		gl.Normal(x * zr0, y * zr0, z0)
                gl.Vertex(x * zr0, y * zr0, z0)
                gl.Normal(x * zr1, y * zr1, z1)
                gl.Vertex(x * zr1, y * zr1, z1)
        	end
        
        gl.End()
	end
end

-------------------------------------------------

local 
function drawPlane()
    gl.Color(1.0, 1.0, 1.0, 0.08)
	gl.Enable(GL.BLEND)
	gl.Disable(GL.DEPTH_TEST)
	gl.BlendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		
    
    for p=0, tpd:planeCount()-1 do
        
		
		local depth = tpd:planeDepth(p)
		
		gl.Begin(GL.POLYGON)
			gl.Vertex(0.0, AREA, depth)
			gl.Vertex(0.0, 0.0, depth)
			gl.Vertex(AREA, 0.0, depth)
			gl.Vertex(AREA, AREA, depth)	
	   gl.End()
	   
	   
	   
	   if( p == activePlane) then gl.Color(1.0, 0.4, 0.1, 0.2) 
	   else  gl.Color(1.0, 1.0, 1.0, 0.2) end
	   gl.LineWidth(0.5)
	   --[[
	   gl.Begin(GL.LINE_STRIP)
			gl.Vertex(0.0, AREA, depth)
			gl.Vertex(0.0, 0.0, depth)
			gl.Vertex(AREA, 0.0, depth)
			gl.Vertex(AREA, AREA, depth)	
			gl.Vertex(0.0, AREA, depth)
	   gl.End()
	   --]]
	   
	   gl.Begin(GL.LINES)
	   		for div=0, AREA, 0.5 do
	   		  gl.Vertex(div, AREA, depth)
	   		  gl.Vertex(div, 0.0, depth)
	   		  
	   		  gl.Vertex(AREA, div, depth)
	   		  gl.Vertex(0.0, div, depth)
	   		end
	   gl.End()
    end
    
    gl.Enable(GL.DEPTH_TEST)
	gl.Disable(GL.BLEND)
end


local 
function drawlabelbg(p, len)
		gl.PushMatrix()
		gl.Translate(p)
		gl.Color(0.0, 0.0, 0.0)
		gl.Begin(GL.POLYGON)
			gl.Vertex(0.0, 0.1, 0.0)
			gl.Vertex(0.0, 0.0, 0.0)
			gl.Vertex(len, 0.0, 0.0)
			gl.Vertex(len, 0.1, 0.0)	
	   gl.End()
	   gl.PopMatrix()

end
-------------------------------------------------

local 
function drawAxes()
	
	local dim = win.dim
	local pos = glu.UnProject(50.0, dim[2] - 50.0, 0.5)
	local sc = 0.02

	gl.Begin(GL.LINES)
	    gl.Color(1.0, 0.0, 0.0)
		gl.Vertex(pos[1], pos[2], pos[3]);
		gl.Vertex(pos[1]+sc, pos[2], pos[3]);
	
	
	    gl.Color(0.0, 1.0, 0.0)
		gl.Vertex(pos[1], pos[2], pos[3]);
		gl.Vertex(pos[1], pos[2]+sc, pos[3]);
	
	    gl.Color(0.0, 0.0, 1.0)
		gl.Vertex(pos[1], pos[2], pos[3]);
		gl.Vertex(pos[1], pos[2], pos[3]+sc);
			
	gl.End()
end

---------------------------------------------------


local shader = Shader{
	ctx = context,
	file = LuaAV.findfile("mat.phong.shl"),
	param = {
		La = {0.2, 0.2, 0.2},
	}
}

local primshader = Shader{
	ctx = context,
	file = LuaAV.findfile("stylized_line.shl"),
	param = {
		haloColor = {0.4, 0.4, 0.4, 1.0},
	}
}

local SPshade = Shader{
	ctx = context,
	file = LuaAV.findfile("stylized_primitive.shl")
}


SPshade:param("radyus", 0.005) 
SPshade:param ("Kd", {0.4, 0.7, 0.55})


shader:param ("Ka", {0.3, 0.3, 0.3})
shader:param ("Kd", {0.7, 0.4, 0.4})
shader:param ("Ks", {0.4, 0.4, 0.4})


-------------------------------------------------

local coolingschedule = {}


local 
function drawCooling()
	local dim = win.dim
	local aspect = dim[1]/dim[2]
	sketch.enter_ortho(-aspect, -1, 2*aspect, 2)
	
	gl.PointSize(1.0)
	gl.Color(1.0, 0.0, 0.0)
	gl.Begin(GL.POINTS)
	
	for k,v in pairs(coolingschedule) do 
		--print(k,v) 
		gl.Vertex(k*0.002-0.9, v*0.1-0.7, 0.0)
	end
	gl.End()
	
	sketch.leave_ortho()
end

-------------------------------------------------
---------calculate ray intersection--------------

local function rayintersect(raypoint, raydir, spherepoint, sphereradius)

    local a = vec3.dot(raydir, raydir)
    local zz = vec3.sub(raypoint, spherepoint)
    local b = 2 * vec3.dot(raydir, zz)
    local c = vec3.dot(zz, zz) - sphereradius* sphereradius
  
    local discriminant = b*b - 4*a*c
    local intersects = false
    
    if( discriminant < 0.0) then 
		intersectres = false
	else
		intersectres = true
	end
    
	return intersectres
end



local 
function selectNode()
		
	    local p1, p2 = cam:picktheray(lastx, lasty)
		cvec1 = p1[1]
		cvec2 = p2[1]
		
		ray = vec3.sub(cvec2, cvec1)
		local rayscale = vec3.scale (ray, 0.01)
		
		
		for l=1, tpd:graphsize() do
			local ind = l-1
			local p = tpd:graphnodepos(ind)
			
			local intersects = rayintersect(cvec1, ray, p, 0.02)
			--print(ind, " intersects=", intersects)
			if(intersects) then
				selectednodeindex = ind
				break
			else
				selectednodeindex = -1
			end
	    end
	    
	    tpd:selectedNode(selectednodeindex)
end

-------------------------------------------------


local ambientLight = { 0.3, 0.3, 0.3, 1.0 }
local diffuseLight = { 0.9, 0.9, 0.9, 1.0 }
local specularLight = { 0.5, 0.8, 0.9, 1.0 }
local position = { 0.0, 2.0, 2.0, 1.0 }


function win:init()
       --Assign created components to GL_LIGHT0
    
end


---------------------------------------------------

tpd:initGraphLayout()
tpd:randomizeGraph(layout3d)

---------------------------------------------------
function win:init()
	gl.Enable(GL.DEPTH_TEST)
	gl.Enable(GL.LIGHTING)
	gl.Enable(GL.LIGHT0)
	
	gl.Light(GL.LIGHT0, GL.AMBIENT, ambientLight)
	gl.Light(GL.LIGHT0, GL.DIFFUSE, diffuseLight)
	gl.Light(GL.LIGHT0, GL.SPECULAR, specularLight)
	gl.Light(GL.LIGHT0, GL.POSITION, position)
	
	gl.Material(GL.FRONT, GL.SHININESS, 100.0)
end

function win:draw(eye)
	
	
	cam:step()
	cam:enter((eye == "left") and 1 or 0)
	
	gl.LineWidth(2.0)
	drawAxes()
	
	local linescale = linethick.value + 0.1
	local pointscale = pointsz.value
	
	drawPlane()
	
	if(boolmousepress) then
	    boolmousepress = false
		selectNode()
	end
			
			
	shader:param ("Kd", {red2[1], red2[2], red2[3]})
	shader:bind()
			tpd:drawGraphNodes(true, 0.002*pointscale)
	shader:unbind()
			
			if(selectednodeindex > -1) then
			    
			    local p = tpd:graphnodepos(selectednodeindex)
			    
			    
			    local labelstr = tpd:getnodelabel(selectednodeindex)
				local chars = string.len(labelstr)
				--print("num chars", chars)
			    p[2] = p[2]+0.01
			    gl.Color(1.0, 1.0, 1.0)
				graphlabels:draw_3d(win.dim, {p[1], p[2], p[3]}, labelstr)
				
				shader:param ("Kd", {yellow2[1], yellow2[2], yellow2[3]})
				shader:bind()
			        
			       
					gl.PushMatrix()
						gl.Translate(p)
						gl.Color(0.3, 0.9, 0.6, 0.9)
						gl.Scale(0.0025*pointscale, 0.0025*pointscale, 0.0025*pointscale)
						drawSphere (1.0, 10, 10)
					gl.PopMatrix()
			    shader:unbind()
			end
			
			
	
		    
		    gl.Color(blue1[1], blue1[2], blue1[3])
		   
		    ----[[
			shapeTexture:bind(0)
			primshader:bind()
				tpd:drawGraphEdges(true, 0.2)
			primshader:unbind()
			shapeTexture:unbind(0)
	        --]]
			gl.Disable(GL.LIGHTING)
			
			
		    --tpd:drawGraphEdges(false, linescale)
			
	
	if(st < MAXSTEP and TEMP > 0.0001) then
	    coolingschedule[st] = TEMP
		--print("step", st, " @ coolexp", coolexp) 
		tpd:stepLayout(layout3d, TEMP)
	 	TEMP = TEMP * 0.98
	 	--TEMP = TEMP * math.exp(-0.0001*st)
	 	st = st+1 	
	end


    cam:leave()
    gl.LineWidth(1.0)
    gl.Color(1.0, 0.0, 0.0)
    sketch.enter_ortho(self.dim)
    guilabels:draw({65, 30, 0}, "Move Node")
	guilabels:draw({65, 50, 0}, "Drag Node")
	guilabels:draw({67, 70, 0}, "Drag Plane")
	
	guilabels:draw({90, 110, 0}, "Edge Color Green Channel")
	guilabels:draw({59, 170, 0}, "Line Thickness")
	guilabels:draw({45, 210, 0}, "Point Size")
	sketch.leave_ortho()
	
	gui:draw()
end