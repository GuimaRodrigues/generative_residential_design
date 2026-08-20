import * as THREE from './vendor/three/three.module.min.js';
import { OrbitControls } from './vendor/three/addons/controls/OrbitControls.js';

const viewers = new WeakMap();
const roomColors = {
  livingRoom: 0xb9d8ca,
  kitchen: 0xd9cda8,
  diningRoom: 0xe2d6b5,
  bedroom: 0xb8cce0,
  masterBedroom: 0xaec4da,
  bathroom: 0xaed5d8,
  toilet: 0xb9dadd,
  laundry: 0xb8d3d5,
  garage: 0xc8cbc8,
  office: 0xd0bfda,
  stairs: 0xd8ceb0,
  hallway: 0xded7c4,
  closet: 0xd7d8cd,
};

class FormaViewer {
  constructor(container, data, onRoomSelected) {
    this.container = container;
    this.data = data;
    this.onRoomSelected = onRoomSelected;
    this.pickableRooms = [];
    this.pointerStart = null;
    this.disposed = false;

    Object.assign(container.style, {
      width: '100%',
      height: '100%',
      minWidth: '1px',
      minHeight: '1px',
      overflow: 'hidden',
      touchAction: 'none',
      cursor: 'grab',
    });

    this.scene = new THREE.Scene();
    this.scene.background = new THREE.Color(0xeceeea);
    this.scene.fog = new THREE.FogExp2(0xeceeea, 0.012);
    this.camera = new THREE.PerspectiveCamera(38, 1, 0.05, 1000);
    this.renderer = new THREE.WebGLRenderer({
      antialias: true,
      alpha: false,
      powerPreference: 'high-performance',
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.05;
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    container.appendChild(this.renderer.domElement);

    this.controls = new OrbitControls(this.camera, this.renderer.domElement);
    this.controls.enableDamping = true;
    this.controls.dampingFactor = 0.075;
    this.controls.minDistance = 4;
    this.controls.maxDistance = 140;
    this.controls.maxPolarAngle = Math.PI * 0.485;
    this.controls.screenSpacePanning = true;
    this.raycaster = new THREE.Raycaster();
    this.pointer = new THREE.Vector2();
    this.modelRoot = new THREE.Group();
    this.scene.add(this.modelRoot);

    this._addLights();
    this._bindEvents();
    this._rebuild();
    this.resetCamera();
    this.resizeObserver = new ResizeObserver(() => this._resize());
    this.resizeObserver.observe(container);
    this._resize();
    this._animate();
  }

  update(data) {
    this.data = data;
    this._rebuild();
  }

  resetCamera() {
    const { site, levels, dimensions } = this.data;
    const centerX = site.width / 2;
    const centerZ = site.depth / 2;
    const maximum = Math.max(site.width, site.depth, 10);
    const buildingHeight =
      Math.max(levels.length - 1, 0) * dimensions.floorToFloorHeight +
      dimensions.wallHeight;
    this.camera.position.set(
      centerX + maximum * 0.88,
      buildingHeight + maximum * 0.72,
      centerZ + maximum * 0.95,
    );
    this.controls.target.set(centerX, buildingHeight * 0.32, centerZ);
    this.controls.update();
  }

  dispose() {
    if (this.disposed) return;
    this.disposed = true;
    cancelAnimationFrame(this.animationFrame);
    this.resizeObserver?.disconnect();
    this.renderer.domElement.removeEventListener('pointerdown', this._onPointerDown);
    this.renderer.domElement.removeEventListener('pointerup', this._onPointerUp);
    this.controls.dispose();
    this._disposeGroup(this.modelRoot);
    this.renderer.dispose();
    this.renderer.domElement.remove();
  }

  _addLights() {
    this.scene.add(new THREE.HemisphereLight(0xf6fbff, 0x76806f, 2.1));
    const sun = new THREE.DirectionalLight(0xfff5df, 3.2);
    sun.position.set(-24, 38, 18);
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    Object.assign(sun.shadow.camera, {
      near: 0.5,
      far: 120,
      left: -40,
      right: 40,
      top: 40,
      bottom: -40,
    });
    sun.shadow.bias = -0.00025;
    this.scene.add(sun);
  }

  _bindEvents() {
    this._onPointerDown = (event) => {
      this.pointerStart = { x: event.clientX, y: event.clientY };
      this.container.style.cursor = 'grabbing';
    };
    this._onPointerUp = (event) => {
      this.container.style.cursor = 'grab';
      if (!this.pointerStart) return;
      const movement = Math.hypot(
        event.clientX - this.pointerStart.x,
        event.clientY - this.pointerStart.y,
      );
      this.pointerStart = null;
      if (movement <= 5) this._selectRoom(event);
    };
    this.renderer.domElement.addEventListener('pointerdown', this._onPointerDown);
    this.renderer.domElement.addEventListener('pointerup', this._onPointerUp);
  }

  _selectRoom(event) {
    const bounds = this.renderer.domElement.getBoundingClientRect();
    if (bounds.width <= 0 || bounds.height <= 0) return;
    this.pointer.x = ((event.clientX - bounds.left) / bounds.width) * 2 - 1;
    this.pointer.y = -((event.clientY - bounds.top) / bounds.height) * 2 + 1;
    this.raycaster.setFromCamera(this.pointer, this.camera);
    const targets = this.pickableRooms.filter(
      (mesh) => mesh.userData.floorIndex === this.data.selection.floorIndex,
    );
    const hit = this.raycaster.intersectObjects(targets, false)[0];
    if (hit) {
      this.onRoomSelected(
        hit.object.userData.roomId,
        hit.object.userData.floorIndex,
      );
    }
  }

  _rebuild() {
    this._disposeGroup(this.modelRoot);
    this.scene.remove(this.modelRoot);
    this.modelRoot = new THREE.Group();
    this.scene.add(this.modelRoot);
    this.pickableRooms = [];
    this._buildSite();
    for (const level of this.data.levels) this._buildLevel(level);
  }

  _buildSite() {
    const site = this.data.site;
    const ground = new THREE.Mesh(
      new THREE.PlaneGeometry(site.width, site.depth),
      new THREE.MeshStandardMaterial({ color: 0xf8faf6, roughness: 0.96 }),
    );
    ground.rotation.x = -Math.PI / 2;
    ground.position.set(site.width / 2, -0.21, site.depth / 2);
    ground.receiveShadow = true;
    this.modelRoot.add(ground);
    this.modelRoot.add(this._rectangleLine(site.bounds, -0.195, 0x536367));
    this.modelRoot.add(
      this._rectangleLine(site.buildableEnvelope, -0.185, 0x89989a, true),
    );
    this._buildGrid(site);
    this._buildStreet(site);
  }

  _buildGrid(site) {
    const points = [];
    for (let x = 1; x < site.width; x += 1) {
      points.push(x, -0.19, 0, x, -0.19, site.depth);
    }
    for (let z = 1; z < site.depth; z += 1) {
      points.push(0, -0.19, z, site.width, -0.19, z);
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', new THREE.Float32BufferAttribute(points, 3));
    this.modelRoot.add(
      new THREE.LineSegments(
        geometry,
        new THREE.LineBasicMaterial({
          color: 0xdfe4df,
          transparent: true,
          opacity: 0.8,
        }),
      ),
    );
  }

  _buildStreet(site) {
    const offset = 0.12;
    let start;
    let end;
    switch (site.streetSide) {
      case 'south':
        start = [0, site.depth - offset];
        end = [site.width, site.depth - offset];
        break;
      case 'east':
        start = [site.width - offset, 0];
        end = [site.width - offset, site.depth];
        break;
      case 'west':
        start = [offset, 0];
        end = [offset, site.depth];
        break;
      default:
        start = [0, offset];
        end = [site.width, offset];
    }
    const geometry = new THREE.BufferGeometry().setFromPoints([
      new THREE.Vector3(start[0], -0.175, start[1]),
      new THREE.Vector3(end[0], -0.175, end[1]),
    ]);
    this.modelRoot.add(
      new THREE.Line(geometry, new THREE.LineBasicMaterial({ color: 0xb55d3f })),
    );
  }

  _buildLevel(level) {
    const active = level.floorIndex === this.data.selection.floorIndex;
    const opacity = active ? 1 : 0.2;
    const group = new THREE.Group();
    group.name = `level-${level.floorIndex}`;
    this.modelRoot.add(group);
    if (level.footprint) {
      const slab = this._boxFromBounds(
        level.footprint,
        level.slabThickness,
        0xd3d8d4,
        opacity,
      );
      slab.position.y = level.elevation - level.slabThickness / 2;
      slab.receiveShadow = true;
      group.add(slab);
    }
    for (const space of level.spaces) {
      const selected = space.id === this.data.selection.roomId;
      const color = selected
        ? 0xc96d49
        : (roomColors[space.roomType] ?? 0xcbd5cf);
      const floor = this._boxFromBounds(
        space.bounds,
        0.055,
        color,
        active ? 0.98 : 0.16,
      );
      floor.position.y = level.elevation + 0.028;
      floor.userData.roomId = space.id;
      floor.userData.floorIndex = level.floorIndex;
      floor.receiveShadow = true;
      this.pickableRooms.push(floor);
      group.add(floor);
      if (active) {
        const label = this._makeLabel(space.label, selected);
        label.position.set(
          space.bounds.x + space.bounds.width / 2,
          level.elevation + 0.22,
          space.bounds.y + space.bounds.height / 2,
        );
        const width = Math.min(Math.max(space.bounds.width * 0.72, 1.2), 3.5);
        label.scale.set(width, width * 0.24, 1);
        group.add(label);
      }
    }
    for (const wall of level.walls) {
      group.add(this._buildWall(wall, level.elevation, opacity));
    }
  }

  _buildWall(wall, elevation, opacity) {
    const deltaX = wall.end.x - wall.start.x;
    const deltaZ = wall.end.y - wall.start.y;
    const length = Math.hypot(deltaX, deltaZ);
    const mesh = new THREE.Mesh(
      new THREE.BoxGeometry(length, wall.height, wall.thickness),
      new THREE.MeshStandardMaterial({
        color: wall.kind === 'exterior' ? 0xf4f0e8 : 0xe5e3dd,
        roughness: 0.82,
        transparent: opacity < 1,
        opacity,
        depthWrite: opacity >= 1,
      }),
    );
    mesh.position.set(
      (wall.start.x + wall.end.x) / 2,
      elevation + wall.height / 2,
      (wall.start.y + wall.end.y) / 2,
    );
    mesh.rotation.y = -Math.atan2(deltaZ, deltaX);
    mesh.castShadow = opacity >= 1;
    mesh.receiveShadow = true;
    return mesh;
  }

  _boxFromBounds(bounds, height, color, opacity) {
    const mesh = new THREE.Mesh(
      new THREE.BoxGeometry(bounds.width, height, bounds.height),
      new THREE.MeshStandardMaterial({
        color,
        roughness: 0.88,
        transparent: opacity < 1,
        opacity,
        depthWrite: opacity >= 1,
      }),
    );
    mesh.position.x = bounds.x + bounds.width / 2;
    mesh.position.z = bounds.y + bounds.height / 2;
    return mesh;
  }

  _rectangleLine(bounds, elevation, color, dashed = false) {
    const geometry = new THREE.BufferGeometry().setFromPoints([
      new THREE.Vector3(bounds.x, elevation, bounds.y),
      new THREE.Vector3(bounds.x + bounds.width, elevation, bounds.y),
      new THREE.Vector3(
        bounds.x + bounds.width,
        elevation,
        bounds.y + bounds.height,
      ),
      new THREE.Vector3(bounds.x, elevation, bounds.y + bounds.height),
    ]);
    const material = dashed
      ? new THREE.LineDashedMaterial({ color, dashSize: 0.35, gapSize: 0.22 })
      : new THREE.LineBasicMaterial({ color });
    const line = new THREE.LineLoop(geometry, material);
    if (dashed) line.computeLineDistances();
    return line;
  }

  _makeLabel(text, selected) {
    const canvas = document.createElement('canvas');
    canvas.width = 512;
    canvas.height = 128;
    const context = canvas.getContext('2d');
    context.clearRect(0, 0, canvas.width, canvas.height);
    context.fillStyle = selected
      ? 'rgba(181,93,63,0.95)'
      : 'rgba(248,250,246,0.9)';
    context.roundRect(4, 4, 504, 120, 14);
    context.fill();
    context.strokeStyle = selected ? '#8f452e' : '#879395';
    context.lineWidth = 3;
    context.stroke();
    context.fillStyle = selected ? '#ffffff' : '#26363a';
    context.font = '700 40px Arial, sans-serif';
    context.textAlign = 'center';
    context.textBaseline = 'middle';
    context.fillText(String(text).toUpperCase(), 256, 65, 480);
    const texture = new THREE.CanvasTexture(canvas);
    texture.colorSpace = THREE.SRGBColorSpace;
    const sprite = new THREE.Sprite(
      new THREE.SpriteMaterial({ map: texture, transparent: true, depthTest: false }),
    );
    sprite.renderOrder = 20;
    return sprite;
  }

  _resize() {
    const width = Math.max(this.container.clientWidth, 1);
    const height = Math.max(this.container.clientHeight, 1);
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
    this.renderer.setSize(width, height, false);
  }

  _animate() {
    if (this.disposed) return;
    this.animationFrame = requestAnimationFrame(() => this._animate());
    this.controls.update();
    this.renderer.render(this.scene, this.camera);
  }

  _disposeGroup(group) {
    group.traverse((object) => {
      object.geometry?.dispose();
      if (!object.material) return;
      const materials = Array.isArray(object.material)
        ? object.material
        : [object.material];
      for (const material of materials) {
        material.map?.dispose();
        material.dispose();
      }
    });
    group.clear();
  }
}

export function create(container, sceneJson, onRoomSelected) {
  dispose(container);
  viewers.set(
    container,
    new FormaViewer(container, JSON.parse(sceneJson), onRoomSelected),
  );
}

export function update(container, sceneJson) {
  viewers.get(container)?.update(JSON.parse(sceneJson));
}

export function resetCamera(container) {
  viewers.get(container)?.resetCamera();
}

export function dispose(container) {
  const viewer = viewers.get(container);
  if (!viewer) return;
  viewer.dispose();
  viewers.delete(container);
}
