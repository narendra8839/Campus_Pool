const express = require('express');
const { listCorridors, getCorridor } = require('../controllers/routeController');

const router = express.Router();
router.get('/corridors', listCorridors);
router.get('/corridors/:id', getCorridor);

module.exports = router;
