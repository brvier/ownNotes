    function beautifulPath(path) {
        var filepath = new String(path);
        filepath = filepath.replace('file://', '');
       filepath = filepath.replace('/home/user', '~');
        
        return filepath;
    }