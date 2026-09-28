const express = require('express');
const { search, reverse } = require('../controllers/geocodingController');

const router = express.Router();
router.get('/search', search);
router.get('/reverse', reverse);

module.exports = router;
