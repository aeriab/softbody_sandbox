# simple_manual_physics_polygon.gd
@tool # Allows drawing in the editor
extends Node2D

# --- Configuration ---
@export var polygon_points: PackedVector2Array = [
	Vector2(-50, -50),  # Top-left (Local Coordinates)
	Vector2(50, -50),   # Top-right
	Vector2(50, 50),    # Bottom-right
	Vector2(-50, 50)   # Bottom-left
] : set = set_polygon_points

@export var polygon_color: Color = Color.DODGER_BLUE
@export var gravity_scale : float = 10.0 # Multiplier for gravity
@export var bounce : float = 0.1       # How much velocity is kept on collision (0=none, 1=perfect bounce)
@export var friction : float = 0.1     # How much horizontal velocity is lost on collision (0=none, 1=immediate stop)
@export var collision_mask: int = 1    # Physics layer(s) this object collides with

# --- Physics State ---
var velocity := Vector2.ZERO
# We need a Shape2D resource for collision detection. Generate it dynamically.
var _collision_shape_resource : ConvexPolygonShape2D # Cache the generated shape

# --- Initialization ---
func _ready():
	# Generate the collision shape resource when the game starts
	_update_collision_shape_resource()

# --- Core Physics Logic ---
func _physics_process(delta: float):
	# Don't run physics simulation in the editor view
	if Engine.is_editor_hint():
		return

	# Ensure we have a valid physics space state
	var space_state = get_world_2d().direct_space_state
	if not space_state:
		printerr("Error: Could not get PhysicsDirectSpaceState2D.")
		return # Cannot perform physics without space state

	# 1. Apply Gravity
	# Get gravity vector from project settings
	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity_vector") * \
				  ProjectSettings.get_setting("physics/2d/default_gravity") * gravity_scale
	velocity += gravity * delta

	# 2. Calculate intended motion for this frame
	var motion = velocity * delta

	# 3. Prepare Collision Check using cast_motion
	if not _collision_shape_resource or _collision_shape_resource.get_rid().is_valid() == false:
		printerr("Error: Invalid collision shape resource for physics check.")
		# Attempt to regenerate, might help if points were set before ready
		_update_collision_shape_resource()
		if not _collision_shape_resource or _collision_shape_resource.get_rid().is_valid() == false:
			return # Still invalid, cannot proceed

	# Set up the query parameters for cast_motion
	var query = PhysicsShapeQueryParameters2D.new()
	query.transform = global_transform  # Current position/rotation/scale
	query.motion = motion               # The movement vector we want to test
	query.shape_rid = _collision_shape_resource.get_rid() # The shape's unique ID
	query.collision_mask = collision_mask # Which physics layers to check against
	# query.exclude = [self.get_instance_id()] # Usually not needed for shapes

	# Perform the collision check
	# cast_motion returns [safe_fraction, unsafe_fraction] or [] if no collision immediately
	var collision_info = space_state.cast_motion(query)

	# 4. Process Collision Result and Move
	if collision_info.is_empty():
		# No collision detected along the motion path
		global_position += motion
	else:
		# Collision occurred!
		var safe_fraction = collision_info[0]
		# Move only by the safe part of the motion
		global_position += motion * safe_fraction

		# --- Collision Response ---
		# Get more detailed info about the *first* collision along the path
		var rest_info = space_state.get_rest_info(query)

		if not rest_info.is_empty():
			var collision_normal = rest_info["normal"]

			# Reflect velocity based on normal and bounce factor
			# Formula: new_velocity = velocity - (1 + bounce) * projection_on_normal * normal
			var projection = velocity.project(collision_normal)
			velocity = velocity - projection * (1.0 + bounce)

			# Apply friction based on the tangent velocity
			var tangent_velocity = velocity - velocity.project(collision_normal)
			velocity -= tangent_velocity * friction

			# A small correction to prevent sticking slightly inside objects sometimes
			# global_position += collision_normal * 0.1 # Adjust value as needed

		else:
			# Fallback if get_rest_info fails (shouldn't usually happen after cast_motion collision)
			# Just stop vertical movement for basic ground collision
			if abs(motion.normalized().dot(Vector2.UP)) > 0.5: # Check if mostly vertical collision
				velocity.y = 0
				velocity.x = lerp(velocity.x, 0.0, friction * 5.0) # Stronger friction on stop
			else: # Wall collision etc.
				velocity = velocity.bounce(Vector2.ZERO) * bounce # Simple bounce off point


	# Note: queue_redraw() is not needed here because the Node2D's position
	# change handles where the _draw function executes. It's only needed
	# if the 'polygon_points' array itself is modified.


# --- Drawing Logic (Unchanged) ---
func _draw():
	if polygon_points.size() < 3:
		for point in polygon_points:
			draw_circle(point, 3.0, Color.RED)
		# print("Need at least 3 points to draw a polygon.") # Reduce console spam
		return

	var colors = PackedColorArray()
	colors.resize(polygon_points.size())
	colors.fill(polygon_color)
	draw_polygon(polygon_points, colors)

	# Optional outline
	draw_polyline(polygon_points, polygon_color.darkened(0.3), 2.0)
	if polygon_points.size() > 1:
		draw_line(polygon_points[-1], polygon_points[0], polygon_color.darkened(0.3), 2.0)


# --- Helper Functions ---

# Called when 'polygon_points' changes via Inspector or code
func set_polygon_points(value: PackedVector2Array):
	polygon_points = value
	_update_collision_shape_resource() # Regenerate shape when points change
	if is_inside_tree():
		queue_redraw() # Update drawing visually

# Creates/updates the Shape2D resource used for collision detection
func _update_collision_shape_resource():
	# Need at least 3 points for a valid polygon shape
	if polygon_points.size() < 3:
		_collision_shape_resource = null # Invalidate shape if points are insufficient
		printerr("Warning: Less than 3 points, cannot create collision shape.")
		return

	# Create the resource if it doesn't exist
	if not _collision_shape_resource:
		# ConvexPolygonShape2D is generally better for performance than CollisionPolygon2D
		# if your shape is convex or doesn't need to handle concave collisions precisely.
		_collision_shape_resource = ConvexPolygonShape2D.new()

	# Update the points of the shape resource
	# Important: This assumes the points define a convex shape.
	# If your shape might be concave, you might need CollisionPolygon2D,
	# but manual physics with concave shapes is more complex.
	_collision_shape_resource.points = polygon_points


# Function to modify the shape (kept from previous example)
func edit_local_shape_point(index: int, new_local_position: Vector2):
	"""Edits the local position of a vertex in the polygon shape AND updates collision."""
	if index >= 0 and index < polygon_points.size():
		polygon_points[index] = new_local_position
		_update_collision_shape_resource() # Regenerate shape resource
		queue_redraw() # Redraw the visual shape
	else:
		printerr("Invalid point index for editing shape: ", index)
